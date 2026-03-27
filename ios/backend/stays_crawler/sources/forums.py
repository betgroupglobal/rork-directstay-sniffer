from __future__ import annotations

from urllib.parse import quote_plus

from stays_crawler.extract import extract_links, is_likely_booking_url, normalize_url
from stays_crawler.fetcher import HttpFetcher
from stays_crawler.models import CrawlRequest, SeedHit
from stays_crawler.sources.base import SearchSource


class ForumTemplateSource(SearchSource):
    name = "forums"

    def __init__(self, fetcher: HttpFetcher) -> None:
        self.fetcher = fetcher

    def discover(self, request: CrawlRequest) -> list[SeedHit]:
        if not request.forum_search_templates:
            return []
        query = _forum_query(request)
        hits: list[SeedHit] = []
        for template in request.forum_search_templates:
            endpoint = template.replace("{query}", quote_plus(query))
            page = self.fetcher.fetch(endpoint)
            if not page or page.status >= 400:
                continue
            for link, text in extract_links(page.text, endpoint):
                if is_likely_booking_url(link, text) or request.location.lower() in (text or "").lower():
                    hits.append(SeedHit(url=normalize_url(link), source=self.name, title=text[:220], snippet=""))
        return hits


def _forum_query(request: CrawlRequest) -> str:
    parts = [request.location, "holiday rental", "owner direct"]
    if request.check_in and request.check_out:
        parts.append(f"{request.check_in} {request.check_out}")
    return " ".join(parts)
