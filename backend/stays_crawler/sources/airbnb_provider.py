from __future__ import annotations

import json
import urllib.error
import urllib.parse
import urllib.request

from stays_crawler.extract import is_direct_property_url, normalize_url
from stays_crawler.models import CrawlRequest, SeedHit
from stays_crawler.sources.base import SearchSource


class AirbnbProviderSource(SearchSource):
    name = "airbnb_provider"

    def __init__(
        self,
        provider: str | None,
        api_key: str | None,
        timeout_seconds: int = 10,
    ) -> None:
        value = (provider or "searchapi").strip().lower()
        self.provider = value if value in {"searchapi", "airroi"} else "searchapi"
        self.api_key = (api_key or "").strip()
        self.timeout_seconds = timeout_seconds

    def discover(self, request: CrawlRequest) -> list[SeedHit]:
        if not self.api_key:
            return []
        if self.provider == "airroi":
            return self._discover_airroi(request)
        return self._discover_searchapi(request)

    def _discover_searchapi(self, request: CrawlRequest) -> list[SeedHit]:
        params: dict[str, str] = {
            "engine": "airbnb",
            "q": request.location,
            "api_key": self.api_key,
        }
        if request.check_in:
            params["check_in_date"] = request.check_in
        if request.check_out:
            params["check_out_date"] = request.check_out
        if request.guests is not None:
            params["adults"] = str(request.guests)
        if request.bedrooms is not None:
            params["bedrooms"] = str(request.bedrooms)
        if request.bathrooms is not None:
            params["bathrooms"] = str(request.bathrooms)
        url = f"https://www.searchapi.io/api/v1/search?{urllib.parse.urlencode(params)}"
        payload = self._request_json("GET", url, headers={"Accept": "application/json"})
        if not isinstance(payload, dict):
            return []
        listings = payload.get("properties") or payload.get("results") or []
        if not isinstance(listings, list):
            return []
        hits: list[SeedHit] = []
        for item in listings:
            if not isinstance(item, dict):
                continue
            title = str(item.get("title") or item.get("name") or "Airbnb listing").strip()[:220]
            for candidate in (item.get("booking_link"), item.get("link"), item.get("url")):
                if not isinstance(candidate, str):
                    continue
                normalized = normalize_url(candidate)
                if not is_direct_property_url(normalized):
                    continue
                hits.append(SeedHit(url=normalized, source=self.name, title=title, snippet="SearchApi Airbnb"))
        return _dedupe_by_url(hits)

    def _discover_airroi(self, request: CrawlRequest) -> list[SeedHit]:
        payload = {
            "market": {"locality": request.location},
            "pagination": {"page_size": max(10, min(50, request.max_results)), "offset": 0},
        }
        if request.bedrooms is not None or request.bathrooms is not None or request.guests is not None:
            filters: dict[str, dict] = {}
            if request.bedrooms is not None:
                filters["bedrooms"] = {"gte": request.bedrooms}
            if request.bathrooms is not None:
                filters["baths"] = {"gte": request.bathrooms}
            if request.guests is not None:
                filters["guests"] = {"gte": request.guests}
            payload["filter"] = filters
        response = self._request_json(
            "POST",
            "https://api.airroi.com/listings/search/market",
            headers={"Accept": "application/json", "Content-Type": "application/json", "X-API-KEY": self.api_key},
            body=json.dumps(payload).encode("utf-8"),
        )
        if not isinstance(response, dict):
            return []
        listings = response.get("results") or response.get("listings") or []
        if not isinstance(listings, list):
            return []
        hits: list[SeedHit] = []
        for item in listings:
            if not isinstance(item, dict):
                continue
            listing_info = item.get("listing_info") if isinstance(item.get("listing_info"), dict) else {}
            listing_id = listing_info.get("listing_id")
            title = str(listing_info.get("listing_name") or "Airbnb listing").strip()[:220]
            if listing_id is None:
                continue
            url = normalize_url(f"https://www.airbnb.com/rooms/{listing_id}")
            if not is_direct_property_url(url):
                continue
            hits.append(SeedHit(url=url, source=self.name, title=title, snippet="AirROI Airbnb"))
        return _dedupe_by_url(hits)

    def _request_json(self, method: str, url: str, headers: dict[str, str], body: bytes | None = None) -> dict | list | None:
        req = urllib.request.Request(url=url, method=method, headers=headers, data=body)
        try:
            with urllib.request.urlopen(req, timeout=self.timeout_seconds) as resp:
                text = resp.read().decode("utf-8", errors="replace")
                return json.loads(text)
        except (urllib.error.HTTPError, urllib.error.URLError, ValueError, json.JSONDecodeError, TimeoutError):
            return None


def _dedupe_by_url(hits: list[SeedHit]) -> list[SeedHit]:
    out: list[SeedHit] = []
    seen: set[str] = set()
    for hit in hits:
        if hit.url in seen:
            continue
        out.append(hit)
        seen.add(hit.url)
    return out
