from __future__ import annotations

import json
import urllib.error
import urllib.parse
import urllib.request

from stays_crawler.extract import is_direct_property_url, normalize_url
from stays_crawler.models import CrawlRequest, SeedHit
from stays_crawler.sources.base import SearchSource


class AirbnbApiSource(SearchSource):
    name = "airbnb_api"

    def __init__(
        self,
        api_base: str | None,
        api_key: str | None = None,
        timeout_seconds: int = 10,
    ) -> None:
        self.api_base = (api_base or "").strip().rstrip("/")
        self.api_key = (api_key or "").strip()
        self.timeout_seconds = timeout_seconds

    def discover(self, request: CrawlRequest) -> list[SeedHit]:
        if not self.api_base:
            return []
        params = {"location": request.location, "q": request.location}
        if request.check_in:
            params["check_in"] = request.check_in
        if request.check_out:
            params["check_out"] = request.check_out
        if request.guests is not None:
            params["guests"] = str(request.guests)
        if request.bedrooms is not None:
            params["bedrooms"] = str(request.bedrooms)
        if request.bathrooms is not None:
            params["bathrooms"] = str(request.bathrooms)
        headers = {"Accept": "application/json"}
        if self.api_key:
            headers["Authorization"] = f"Bearer {self.api_key}"
            headers["X-API-Key"] = self.api_key
        payload = self._request_json(f"{self.api_base}/search?{urllib.parse.urlencode(params)}", headers)
        if not isinstance(payload, dict):
            return []
        listings = payload.get("results") or payload.get("data") or payload.get("listings") or payload.get("homes") or []
        if isinstance(listings, dict):
            listings = listings.get("items") or listings.get("results") or []
        if not isinstance(listings, list):
            return []
        hits: list[SeedHit] = []
        for item in listings:
            if not isinstance(item, dict):
                continue
            title = str(item.get("title") or item.get("name") or item.get("listingName") or "Airbnb listing").strip()[:220]
            for url in _extract_listing_urls(item):
                normalized = normalize_url(url)
                if not is_direct_property_url(normalized):
                    continue
                hits.append(SeedHit(url=normalized, source=self.name, title=title, snippet="Airbnb API"))
        return _dedupe_by_url(hits)

    def _request_json(self, url: str, headers: dict[str, str]) -> dict | list | None:
        req = urllib.request.Request(url=url, method="GET", headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=self.timeout_seconds) as resp:
                text = resp.read().decode("utf-8", errors="replace")
                return json.loads(text)
        except (urllib.error.HTTPError, urllib.error.URLError, ValueError, json.JSONDecodeError, TimeoutError):
            return None


def _extract_listing_urls(item: dict) -> list[str]:
    candidates: list[str] = []
    direct_keys = (
        "url",
        "listingUrl",
        "listingURL",
        "airbnbListingUrl",
        "airbnbUrl",
        "airbnbURL",
        "deeplink",
    )
    for key in direct_keys:
        value = item.get(key)
        if isinstance(value, str) and value.startswith(("http://", "https://")):
            candidates.append(value)
    listing = item.get("listing")
    if isinstance(listing, dict):
        for value in listing.values():
            if isinstance(value, str) and value.startswith(("http://", "https://")):
                candidates.append(value)
    return candidates


def _dedupe_by_url(hits: list[SeedHit]) -> list[SeedHit]:
    out: list[SeedHit] = []
    seen: set[str] = set()
    for hit in hits:
        if hit.url in seen:
            continue
        out.append(hit)
        seen.add(hit.url)
    return out
