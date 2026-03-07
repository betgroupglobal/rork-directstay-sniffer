from __future__ import annotations

from collections import defaultdict
from urllib.parse import urlparse

from stays_crawler.extract import (
    compute_relevance,
    extract_estimated_cost,
    extract_links,
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
        pages_per_source = self.default_pages_per_source if request.max_pages_per_source is None else max(1, request.max_pages_per_source)
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
        processed_by_source: dict[str, int] = defaultdict(int)
        while True:
            item = self.store.pop_next_pending(request_key)
            if item is None:
                break
            if processed_by_source[item.source] >= pages_per_source:
                self.store.mark_done(item.item_id)
                continue
            processed_by_source[item.source] += 1
            for hit in self._scan_item(item, request, query_terms, depth_limit, request_key):
                if request.exclude_ota and is_ota_url(hit.booking_url):
                    continue
                existing = scored.get(hit.booking_url)
                if existing is None or hit.score > existing.score:
                    scored[hit.booking_url] = hit
            self.store.mark_done(item.item_id)
        results = sorted(scored.values(), key=lambda hit: hit.score, reverse=True)
        response = CrawlResponse(query=" ".join(query_terms), total=min(len(results), request.max_results), results=results[: request.max_results])
        self.store.set_cached_response(request_key, response)
        return response

    def _scan_item(self, item: QueueItem, request: CrawlRequest, query_terms: list[str], depth_limit: int, request_key: str) -> list[BookingHit]:
        current_url = normalize_url(item.url)
        page = self.fetcher.fetch(current_url)
        if not page or page.status >= 400:
            return []
        snippet = page.text[:1200]
        title = item.title or ""
        image_url, image_description = extract_primary_image_details(page.text)
        estimated_cost = extract_estimated_cost(page.text, request.check_in, request.check_out)
        outputs: list[BookingHit] = []
        score, matched = compute_relevance(title, snippet, query_terms, current_url)
        if is_direct_property_url(current_url) and score > 0:
            outputs.append(
                BookingHit(
                    booking_url=current_url,
                    source=item.source,
                    discovered_on=current_url,
                    title=title[:220],
                    snippet=snippet[:300],
                    score=score,
                    matched_terms=matched,
                    image_url=image_url,
                    image_description=image_description,
                    estimated_cost=estimated_cost,
                )
            )
        links = extract_links(page.text, current_url)
        queued_links: list[tuple[str, str, str]] = []
        for link, anchor_text in links:
            link_score, link_matched = compute_relevance(anchor_text, snippet[:240], query_terms, link)
            if is_direct_property_url(link) and link_score > 0:
                outputs.append(
                    BookingHit(
                        booking_url=link,
                        source=item.source,
                        discovered_on=current_url,
                        title=anchor_text[:220] or title[:220],
                        snippet=snippet[:300],
                        score=link_score + 1.0,
                        matched_terms=link_matched,
                        image_url=image_url,
                        image_description=image_description,
                        estimated_cost=estimated_cost,
                    )
                )
            if item.depth < depth_limit and _is_same_site(current_url, link):
                queued_links.append((link, item.source, anchor_text[:220] or title[:220]))
        if queued_links:
            self.store.enqueue_links(request_key, queued_links, depth=item.depth + 1)
        return outputs

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
        dedup: list[str] = []
        seen: set[str] = set()
        for token in tokenize(" ".join(parts)):
            if token not in seen:
                dedup.append(token)
                seen.add(token)
        return dedup


def _is_same_site(source: str, target: str) -> bool:
    return urlparse(source).netloc.lower() == urlparse(target).netloc.lower()


def _trim(response: CrawlResponse, max_results: int) -> CrawlResponse:
    trimmed = response.results[:max_results]
    return CrawlResponse(query=response.query, total=len(trimmed), results=trimmed)
