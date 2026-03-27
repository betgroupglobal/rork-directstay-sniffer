from __future__ import annotations

import json
import time
import urllib.error
import urllib.parse
import urllib.request

from stays_crawler.extract import is_direct_property_url, normalize_url
from stays_crawler.models import CrawlRequest, SeedHit
from stays_crawler.storage import CrawlStore
from stays_crawler.sources.base import SearchSource


class GuestySource(SearchSource):
    name = "guesty"

    def __init__(
        self,
        store: CrawlStore,
        client_id: str | None,
        client_secret: str | None,
        api_base: str = "https://open-api.guesty.com",
        timeout_seconds: int = 10,
    ) -> None:
        self.store = store
        self.client_id = (client_id or "").strip()
        self.client_secret = (client_secret or "").strip()
        self.api_base = api_base.rstrip("/")
        self.timeout_seconds = timeout_seconds
        self._access_token: str | None = None
        self._token_expires_at: float = 0

    def discover(self, request: CrawlRequest) -> list[SeedHit]:
        seeds = self.store.list_external_seeds(source=self.name, location=request.location, limit=max(20, request.max_results * 3))
        if not self.client_id or not self.client_secret:
            return seeds
        token = self._get_access_token()
        if not token:
            return seeds
        headers = {"Accept": "application/json", "Authorization": f"Bearer {token}"}
        payload = self._request_json("GET", f"{self.api_base}/v1/listings", headers=headers)
        if not isinstance(payload, dict):
            return seeds
        listings = payload.get("results") or payload.get("data") or payload.get("listings") or []
        if not isinstance(listings, list):
            return seeds
        location_low = request.location.lower()
        for item in listings:
            if not isinstance(item, dict):
                continue
            title = _string(item.get("title") or item.get("nickname") or item.get("name") or "Guesty listing")[:220]
            text_blob = json.dumps(item).lower()
            if location_low and location_low not in text_blob:
                continue
            for url in _extract_listing_urls(item):
                normalized = normalize_url(url)
                if not is_direct_property_url(normalized):
                    continue
                seeds.append(SeedHit(url=normalized, source=self.name, title=title, snippet="Guesty listing"))
        return _dedupe_by_url(seeds)

    def _get_access_token(self) -> str | None:
        now = time.time()
        if self._access_token and now < self._token_expires_at:
            return self._access_token
        payload = urllib.parse.urlencode(
            {
                "grant_type": "client_credentials",
                "scope": "open-api",
                "client_secret": self.client_secret,
                "client_id": self.client_id,
            }
        ).encode("utf-8")
        headers = {"Accept": "application/json", "Content-Type": "application/x-www-form-urlencoded"}
        token_data = self._request_json("POST", f"{self.api_base}/oauth2/token", headers=headers, body=payload)
        if not isinstance(token_data, dict):
            return None
        token = _string(token_data.get("access_token"))
        expires_in = int(token_data.get("expires_in", 3600) or 3600)
        if not token:
            return None
        self._access_token = token
        self._token_expires_at = now + max(60, expires_in - 900)
        return token

    def _request_json(self, method: str, url: str, headers: dict[str, str], body: bytes | None = None) -> dict | list | None:
        req = urllib.request.Request(url=url, method=method, headers=headers, data=body)
        try:
            with urllib.request.urlopen(req, timeout=self.timeout_seconds) as resp:
                text = resp.read().decode("utf-8", errors="replace")
                return json.loads(text)
        except (urllib.error.HTTPError, urllib.error.URLError, ValueError, json.JSONDecodeError, TimeoutError):
            return None


def _extract_listing_urls(item: dict) -> list[str]:
    candidates: list[str] = []
    direct_keys = (
        "publicUrl",
        "publicURL",
        "bookingUrl",
        "bookingURL",
        "directBookingUrl",
        "directBookingURL",
        "airbnbListingUrl",
        "airbnbUrl",
        "bookingComListingUrl",
        "vrboListingUrl",
        "listingUrl",
        "url",
    )
    for key in direct_keys:
        value = item.get(key)
        if isinstance(value, str) and value.startswith(("http://", "https://")):
            candidates.append(value)
    integrations = item.get("integrations")
    if isinstance(integrations, dict):
        for _, value in integrations.items():
            if isinstance(value, str) and value.startswith(("http://", "https://")):
                candidates.append(value)
            if isinstance(value, dict):
                for sub_value in value.values():
                    if isinstance(sub_value, str) and sub_value.startswith(("http://", "https://")):
                        candidates.append(sub_value)
    return candidates


def _dedupe_by_url(seeds: list[SeedHit]) -> list[SeedHit]:
    out: list[SeedHit] = []
    seen: set[str] = set()
    for seed in seeds:
        if seed.url in seen:
            continue
        out.append(seed)
        seen.add(seed.url)
    return out


def _string(value: object) -> str:
    return str(value).strip() if value is not None else ""
