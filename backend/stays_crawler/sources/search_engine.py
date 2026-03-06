from __future__ import annotations

from urllib.parse import parse_qs, quote_plus, urlparse

from stays_crawler.extract import extract_links, normalize_url
from stays_crawler.fetcher import HttpFetcher
from stays_crawler.models import CrawlRequest, SeedHit
from stays_crawler.sources.base import SearchSource


class DuckDuckGoSource(SearchSource):
    name = "search_engine"

    def __init__(self, fetcher: HttpFetcher) -> None:
        self.fetcher = fetcher

    def discover(self, request: CrawlRequest) -> list[SeedHit]:
        query = build_query(request)
        url = f"https://duckduckgo.com/html/?q={quote_plus(query)}"
        page = self.fetcher.fetch(url)
        if not page or page.status >= 400:
            return []
        hits: list[SeedHit] = []
        for link, text in extract_links(page.text, url):
            resolved = _resolve_duckduckgo_redirect(link)
            if not resolved:
                continue
            hits.append(SeedHit(url=normalize_url(resolved), source=self.name, title=text.strip()[:220], snippet=""))
        return hits


def build_query(request: CrawlRequest) -> str:
    parts = [request.location, "holiday rental", "direct booking"]
    if request.bedrooms:
        parts.append(f"{request.bedrooms} bedroom")
    if request.bathrooms:
        parts.append(f"{request.bathrooms} bathroom")
    if request.pet_friendly:
        parts.append("pet friendly")
    if request.whole_home:
        parts.append("whole home")
    return " ".join(p for p in parts if p)


def _resolve_duckduckgo_redirect(url: str) -> str | None:
    parsed = urlparse(url)
    if "duckduckgo.com" not in parsed.netloc:
        return url
    params = parse_qs(parsed.query)
    target = params.get("uddg", [None])[0]
    if target:
        return target
    return None
