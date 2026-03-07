from __future__ import annotations

from collections import defaultdict
from urllib.parse import urlparse

from stays_crawler.extract import (
    compute_relevance,
    extract_estimated_cost,
    extract_links,
    extract_page_description,
    extract_page_title,
    extract_primary_image_details,
    is_direct_property_url,
    is_ota_url,
    normalize_url,
    tokenize,
)
from stays_crawler.fetcher import HttpFetcher
from stays_crawler.models import BookingHit, CrawlRequest, CrawlResponse, SeedHit
from stays_crawler.sources.airbnb_provider import AirbnbProviderSource
from stays_crawler.sources.base import SearchSource
from stays_crawler.sources.forums import ForumTemplateSource
from stays_crawler.sources.guesty import GuestySource
from stays_crawler.sources.providers import ProviderSeedSource
from stays_crawler.sources.search_engine import DuckDuckGoSource
from stays_crawler.sources.social import RedditSocialSource
from stays_crawler.storage import CrawlStore, QueueItem


class StaysCrawler:
    def __init__(
        self,
        fetcher: HttpFetcher,
        default_depth: int = 1,
        default_pages_per_source: int = 20,
        store: CrawlStore | None = None,
        cache_ttl_seconds: int = 900,
        guesty_client_id: str | None = None,
        guesty_client_secret: str | None = None,
        guesty_api_base: str = "https://open-api.guesty.com",
        airbnb_provider: str | None = None,
        airbnb_api_key: str | None = None,
    ) -> None:
        self.fetcher = fetcher
        self.default_depth = max(0, default_depth)
        self.default_pages_per_source = max(1, default_pages_per_source)
        self.store = store or CrawlStore(":memory:")
        self.cache_ttl_seconds = max(0, cache_ttl_seconds)
        self.guesty_client_id = guesty_client_id
        self.guesty_client_secret = guesty_client_secret
        self.guesty_api_base = guesty_api_base
        self.airbnb_provider = airbnb_provider
        self.airbnb_api_key = airbnb_api_key

    def crawl(self, request: CrawlRequest) -> CrawlResponse:
        depth_limit = self.default_depth if request.crawl_depth is None else max(0, request.crawl_depth)
        depth_limit = min(1, depth_limit)
        pages_per_source = self.default_pages_per_source if request.max_pages_per_source is None else max(1, request.max_pages_per_source)
        if request.direct_hunter:
            pages_per_source = max(60, pages_per_source)
        request_key = self.store.make_request_key(request)
        cached = self.store.get_cached_response(request_key, self.cache_ttl_seconds)
        if cached is not None:
            return _trim(cached, request.max_results)
        sources = self._build_sources()
        all_seed_hits: list[SeedHit] = []
        for source in sources:
            all_seed_hits.extend(source.discover(request))
        self.store.reset_processing(request_key)
        self.store.enqueue_seeds(request_key, all_seed_hits, depth=0)
        query_terms = self._build_terms(request)
        scored: dict[str, BookingHit] = {}
        parsed_result_cache: dict[str, dict[str, str | None]] = {}
        processed_by_source: dict[str, int] = defaultdict(int)
        while True:
            item = self.store.pop_next_pending(request_key)
            if item is None:
                break
            if processed_by_source[item.source] >= pages_per_source:
                self.store.mark_done(item.item_id)
                continue
            processed_by_source[item.source] += 1
            for hit in self._scan_item(item, request, query_terms, depth_limit, request_key, parsed_result_cache):
                if request.exclude_ota and is_ota_url(hit.booking_url):
                    continue
                if request.direct_hunter:
                    hit = self._apply_direct_hunter_boosts(hit)
                existing = scored.get(hit.booking_url)
                if existing is None or hit.score > existing.score:
                    scored[hit.booking_url] = hit
            self.store.mark_done(item.item_id)
        results = sorted(scored.values(), key=lambda hit: hit.score, reverse=True)
        response = CrawlResponse(query=" ".join(query_terms), total=min(len(results), request.max_results), results=results[: request.max_results])
        self.store.set_cached_response(request_key, response)
        return response

    def _scan_item(
        self,
        item: QueueItem,
        request: CrawlRequest,
        query_terms: list[str],
        depth_limit: int,
        request_key: str,
        parsed_result_cache: dict[str, dict[str, str | None]],
    ) -> list[BookingHit]:
        current_url = normalize_url(item.url)
        page = self.fetcher.fetch(current_url)
        if not page or page.status >= 400:
            return []
        snippet = page.text[:1200]
        page_title = extract_page_title(page.text)
        page_description = extract_page_description(page.text)
        base_title = (item.title or page_title or current_url)[:220]
        base_snippet = (page_description or snippet[:300]).strip()[:300]
        outputs: list[BookingHit] = []
        score, matched = compute_relevance(base_title, snippet, query_terms, current_url)
        if is_direct_property_url(current_url) and score > 0:
            hit = BookingHit(
                booking_url=current_url,
                source=item.source,
                discovered_on=current_url,
                title=base_title,
                snippet=base_snippet,
                score=score,
                matched_terms=matched,
            )
            outputs.append(self._enrich_result_hit(hit, request, parsed_result_cache, prefetched_html=page.text))
        links = extract_links(page.text, current_url)
        queued_links: list[tuple[str, str, str]] = []
        for link, anchor_text in links:
            link_score, link_matched = compute_relevance(anchor_text, snippet[:240], query_terms, link)
            if is_direct_property_url(link) and link_score > 0:
                hit = BookingHit(
                    booking_url=link,
                    source=item.source,
                    discovered_on=current_url,
                    title=(anchor_text[:220] or base_title),
                    snippet=base_snippet,
                    score=link_score + 1.0,
                    matched_terms=link_matched,
                )
                outputs.append(self._enrich_result_hit(hit, request, parsed_result_cache))
            if item.depth < depth_limit and _is_same_site(current_url, link):
                queued_links.append((link, item.source, anchor_text[:220] or base_title))
        if queued_links:
            self.store.enqueue_links(request_key, queued_links, depth=item.depth + 1)
        return outputs

    def _enrich_result_hit(
        self,
        hit: BookingHit,
        request: CrawlRequest,
        parsed_result_cache: dict[str, dict[str, str | None]],
        prefetched_html: str | None = None,
    ) -> BookingHit:
        key = normalize_url(hit.booking_url)
        cached = parsed_result_cache.get(key)
        if cached is None:
            page_text = prefetched_html
            if page_text is None:
                page = self.fetcher.fetch(key)
                if page is not None and page.status < 400:
                    page_text = page.text
            if page_text is None:
                cached = {
                    "title": None,
                    "snippet": None,
                    "image_url": None,
                    "image_description": None,
                    "estimated_cost": None,
                }
            else:
                parsed_title = extract_page_title(page_text)
                parsed_description = extract_page_description(page_text)
                parsed_image_url, parsed_image_description = extract_primary_image_details(page_text)
                parsed_cost = extract_estimated_cost(page_text, request.check_in, request.check_out)
                cached = {
                    "title": parsed_title,
                    "snippet": parsed_description,
                    "image_url": parsed_image_url,
                    "image_description": parsed_image_description,
                    "estimated_cost": parsed_cost,
                }
            parsed_result_cache[key] = cached

        title = (cached.get("title") or hit.title or key)[:220]
        snippet = (cached.get("snippet") or hit.snippet or "")[:300]
        return BookingHit(
            booking_url=hit.booking_url,
            source=hit.source,
            discovered_on=hit.discovered_on,
            title=title,
            snippet=snippet,
            score=hit.score,
            matched_terms=hit.matched_terms,
            image_url=cached.get("image_url") or hit.image_url,
            image_description=cached.get("image_description") or hit.image_description,
            estimated_cost=cached.get("estimated_cost") or hit.estimated_cost,
        )

    def _apply_direct_hunter_boosts(self, hit: BookingHit) -> BookingHit:
        adjusted = hit.score
        lower_url = hit.booking_url.lower()
        if is_ota_url(lower_url):
            adjusted -= 4.0
        else:
            adjusted += 2.0
        if any(token in lower_url for token in ("/book", "/reserve", "/property", "/listing", "/accommodation")):
            adjusted += 1.25
        if hit.image_url:
            adjusted += 0.35
        if hit.estimated_cost:
            adjusted += 0.35
        return BookingHit(
            booking_url=hit.booking_url,
            source=hit.source,
            discovered_on=hit.discovered_on,
            title=hit.title,
            snippet=hit.snippet,
            score=adjusted,
            matched_terms=hit.matched_terms,
            image_url=hit.image_url,
            image_description=hit.image_description,
            estimated_cost=hit.estimated_cost,
        )

    def _build_sources(self) -> list[SearchSource]:
        return [
            DuckDuckGoSource(self.fetcher),
            AirbnbProviderSource(provider=self.airbnb_provider, api_key=self.airbnb_api_key),
            ProviderSeedSource(),
            GuestySource(
                store=self.store,
                client_id=self.guesty_client_id,
                client_secret=self.guesty_client_secret,
                api_base=self.guesty_api_base,
            ),
            ForumTemplateSource(self.fetcher),
            RedditSocialSource(self.fetcher),
        ]

    def _build_terms(self, request: CrawlRequest) -> list[str]:
        parts: list[str] = [request.location, "direct", "booking", "holiday", "stay"]
        if request.direct_hunter:
            parts.extend(["book direct", "owner direct", "official site", "no service fee", "best direct rate"])
        if request.bedrooms:
            parts.extend([str(request.bedrooms), "bedroom"])
        if request.bathrooms:
            parts.extend([str(request.bathrooms), "bathroom"])
        if request.guests:
            parts.extend([str(request.guests), "guests"])
        if request.pet_friendly:
            parts.extend(["pet", "friendly"])
        if request.whole_home:
            parts.extend(["whole", "home"])
        if request.check_in:
            parts.append(request.check_in)
        if request.check_out:
            parts.append(request.check_out)

        normalized_parts: list[str] = []
        for part in parts:
            value = " ".join(str(part).strip().lower().split())
            if value:
                normalized_parts.append(value)

        dedup: list[str] = []
        seen: set[str] = set()
        for term in normalized_parts + tokenize(" ".join(normalized_parts)):
            if term not in seen:
                dedup.append(term)
                seen.add(term)
        return dedup


def _is_same_site(source: str, target: str) -> bool:
    return urlparse(source).netloc.lower() == urlparse(target).netloc.lower()


def _trim(response: CrawlResponse, max_results: int) -> CrawlResponse:
    trimmed = response.results[:max_results]
    return CrawlResponse(query=response.query, total=len(trimmed), results=trimmed)
