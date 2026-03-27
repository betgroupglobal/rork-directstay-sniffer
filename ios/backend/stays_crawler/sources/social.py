from __future__ import annotations

import json
from urllib.parse import quote_plus

from stays_crawler.extract import extract_links, normalize_url
from stays_crawler.fetcher import HttpFetcher
from stays_crawler.models import CrawlRequest, SeedHit
from stays_crawler.sources.base import SearchSource


class RedditSocialSource(SearchSource):
    name = "social_media"

    def __init__(self, fetcher: HttpFetcher) -> None:
        self.fetcher = fetcher

    def discover(self, request: CrawlRequest) -> list[SeedHit]:
        query = _social_query(request)
        endpoint = f"https://www.reddit.com/search.json?q={quote_plus(query)}&sort=relevance&limit=50"
        page = self.fetcher.fetch(endpoint)
        if not page or page.status >= 400:
            return []
        try:
            payload = json.loads(page.text)
        except json.JSONDecodeError:
            return []
        hits: list[SeedHit] = []
        children = payload.get("data", {}).get("children", [])
        for child in children:
            data = child.get("data", {})
            candidate = data.get("url_overridden_by_dest") or data.get("url")
            title = str(data.get("title", ""))
            snippet = str(data.get("selftext", ""))[:300]
            if candidate:
                hits.append(SeedHit(url=normalize_url(str(candidate)), source=self.name, title=title[:220], snippet=snippet))
        for template in request.social_search_templates:
            endpoint = template.replace("{query}", quote_plus(query))
            page = self.fetcher.fetch(endpoint)
            if not page or page.status >= 400:
                continue
            for link, text in extract_links(page.text, endpoint):
                hits.append(SeedHit(url=normalize_url(link), source=self.name, title=text[:220], snippet=""))
        return hits


def _social_query(request: CrawlRequest) -> str:
    parts = [request.location, "direct booking", "holiday stay"]
    if request.pet_friendly:
        parts.append("pet friendly")
    return " ".join(parts)
