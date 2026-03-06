from __future__ import annotations

from collections import deque
from urllib.parse import urlparse

from stays_crawler.extract import compute_relevance, extract_links, is_likely_booking_url, normalize_url, tokenize
from stays_crawler.fetcher import HttpFetcher
from stays_crawler.models import BookingHit, CrawlRequest, CrawlResponse, SeedHit
from stays_crawler.sources.base import SearchSource
from stays_crawler.sources.forums import ForumTemplateSource
from stays_crawler.sources.search_engine import DuckDuckGoSource
from stays_crawler.sources.social import RedditSocialSource


class StaysCrawler:
    def __init__(self, fetcher: HttpFetcher, default_depth: int = 1, default_pages_per_source: int = 20) -> None:
        self.fetcher = fetcher
        self.default_depth = max(0, default_depth)
        self.default_pages_per_source = max(1, default_pages_per_source)

    def crawl(self, request: CrawlRequest) -> CrawlResponse:
        depth = self.default_depth if request.crawl_depth is None else max(0, request.crawl_depth)
        pages_per_source = self.default_pages_per_source if request.max_pages_per_source is None else max(1, request.max_pages_per_source)
        sources = self._build_sources()
        all_seed_hits: list[SeedHit] = []
        for source in sources:
            all_seed_hits.extend(source.discover(request))
        query_terms = self._build_terms(request)
        scored: dict[str, BookingHit] = {}
        for seed in all_seed_hits:
            for item in self._scan_seed(seed, query_terms, depth, pages_per_source):
                existing = scored.get(item.booking_url)
                if existing is None or item.score > existing.score:
                    scored[item.booking_url] = item
        results = sorted(scored.values(), key=lambda hit: hit.score, reverse=True)[: request.max_results]
        query_text = " ".join(query_terms)
        return CrawlResponse(query=query_text, total=len(results), results=results)

    def _scan_seed(self, seed: SeedHit, query_terms: list[str], max_depth: int, max_pages: int) -> list[BookingHit]:
        queue: deque[tuple[str, int]] = deque([(seed.url, 0)])
        visited: set[str] = set()
        outputs: list[BookingHit] = []
        pages_seen = 0
        while queue and pages_seen < max_pages:
            current_url, depth = queue.popleft()
            current_url = normalize_url(current_url)
            if current_url in visited:
                continue
            visited.add(current_url)
            page = self.fetcher.fetch(current_url)
            if not page or page.status >= 400:
                continue
            pages_seen += 1
            snippet = page.text[:1200]
            title = seed.title
            score, matched = compute_relevance(title, snippet, query_terms, current_url)
            if is_likely_booking_url(current_url, title) and score > 0:
                outputs.append(
                    BookingHit(
                        booking_url=current_url,
                        source=seed.source,
                        discovered_on=current_url,
                        title=title[:220],
                        snippet=snippet[:300],
                        score=score,
                        matched_terms=matched,
                    )
                )
            links = extract_links(page.text, current_url)
            for link, anchor_text in links:
                link_score, link_matched = compute_relevance(anchor_text, snippet[:240], query_terms, link)
                if is_likely_booking_url(link, anchor_text) and link_score > 0:
                    outputs.append(
                        BookingHit(
                            booking_url=link,
                            source=seed.source,
                            discovered_on=current_url,
                            title=anchor_text[:220] or seed.title[:220],
                            snippet=snippet[:300],
                            score=link_score + 1.0,
                            matched_terms=link_matched,
                        )
                    )
                if depth < max_depth and _is_same_site(current_url, link):
                    queue.append((link, depth + 1))
        return outputs

    def _build_sources(self) -> list[SearchSource]:
        return [
            DuckDuckGoSource(self.fetcher),
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
