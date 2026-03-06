from __future__ import annotations

import hashlib
import hmac
import json
import os
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from stays_crawler.crawler import StaysCrawler
from stays_crawler.extract import is_direct_property_url, normalize_url
from stays_crawler.fetcher import HttpFetcher
from stays_crawler.models import CrawlRequest
from stays_crawler.sources.airbnb_provider import AirbnbProviderSource
from stays_crawler.storage import CrawlStore


def build_crawler() -> StaysCrawler:
    timeout = int(os.getenv("CRAWLER_TIMEOUT_SECONDS", "8"))
    depth = int(os.getenv("CRAWLER_DEFAULT_DEPTH", "1"))
    pages = int(os.getenv("CRAWLER_MAX_PAGES_PER_SOURCE", "20"))
    retries = int(os.getenv("CRAWLER_RETRY_COUNT", "2"))
    backoff = float(os.getenv("CRAWLER_RETRY_BACKOFF_SECONDS", "0.5"))
    cache_ttl = int(os.getenv("CRAWLER_CACHE_TTL_SECONDS", "900"))
    ua = os.getenv("CRAWLER_USER_AGENT", "NoPaysStaysCrawler/1.0 (+https://example.com)")
    ua_list = [item.strip() for item in os.getenv("CRAWLER_USER_AGENTS", "").split(",") if item.strip()]
    proxy_list = [item.strip() for item in os.getenv("CRAWLER_PROXIES", "").split(",") if item.strip()]
    db_path = os.getenv("CRAWLER_DB_PATH", "backend/.cache/crawler.db")
    guesty_client_id = os.getenv("GUESTY_CLIENT_ID")
    guesty_client_secret = os.getenv("GUESTY_CLIENT_SECRET")
    guesty_api_base = os.getenv("GUESTY_API_BASE", "https://open-api.guesty.com")
    airbnb_provider = os.getenv("AIRBNB_PROVIDER", "searchapi")
    airbnb_api_key = os.getenv("AIRBNB_API_KEY") or os.getenv("SEARCHAPI_API_KEY") or os.getenv("AIRROI_API_KEY")
    os.makedirs(os.path.dirname(db_path), exist_ok=True)
    fetcher = HttpFetcher(
        user_agent=ua,
        timeout_seconds=timeout,
        retry_count=retries,
        retry_backoff_seconds=backoff,
        user_agents=ua_list or None,
        proxies=proxy_list or None,
    )
    store = CrawlStore(db_path=db_path)
    return StaysCrawler(
        fetcher=fetcher,
        default_depth=depth,
        default_pages_per_source=pages,
        store=store,
        cache_ttl_seconds=cache_ttl,
        guesty_client_id=guesty_client_id,
        guesty_client_secret=guesty_client_secret,
        guesty_api_base=guesty_api_base,
        airbnb_provider=airbnb_provider,
        airbnb_api_key=airbnb_api_key,
    )


def handle_search_payload(payload: dict, crawler: StaysCrawler | None = None) -> tuple[int, dict]:
    service = crawler or build_crawler()
    try:
        req = CrawlRequest.from_payload(payload)
    except (TypeError, ValueError) as exc:
        return HTTPStatus.BAD_REQUEST, {"error": str(exc)}
    response = service.crawl(req)
    return HTTPStatus.OK, response.to_dict()


def handle_airbnb_search_payload(payload: dict, crawler: StaysCrawler | None = None) -> tuple[int, dict]:
    service = crawler or build_crawler()
    try:
        req = CrawlRequest.from_payload(payload)
    except (TypeError, ValueError) as exc:
        return HTTPStatus.BAD_REQUEST, {"error": str(exc)}
    source = AirbnbProviderSource(provider=service.airbnb_provider, api_key=service.airbnb_api_key)
    hits = source.discover(req)
    return HTTPStatus.OK, {
        "source": source.provider,
        "total": len(hits),
        "results": [
            {"url": hit.url, "title": hit.title, "snippet": hit.snippet, "source": hit.source}
            for hit in hits[: req.max_results]
        ],
    }


def handle_guesty_webhook(payload: dict, store: CrawlStore, event_type: str = "") -> tuple[int, dict]:
    candidates = _extract_urls_from_payload(payload)
    saved = 0
    for url in candidates:
        normalized = normalize_url(url)
        if not is_direct_property_url(normalized):
            continue
        title = _best_title(payload)
        location_hint = _best_location(payload)
        snippet = event_type or "guesty webhook"
        store.upsert_external_seed(source="guesty", url=normalized, title=title, snippet=snippet, location_hint=location_hint)
        saved += 1
    return HTTPStatus.OK, {"status": "ok", "saved": saved}


def _verify_guesty_signature(raw_payload: str, signature: str) -> bool:
    secret = os.getenv("GUESTY_WEBHOOK_SECRET", "").strip()
    if not secret:
        return True
    if not signature:
        return False
    expected = hmac.new(secret.encode("utf-8"), raw_payload.encode("utf-8"), hashlib.sha256).hexdigest()
    provided = signature.strip().lower()
    if provided.startswith("sha256="):
        provided = provided.split("=", 1)[1]
    return hmac.compare_digest(expected, provided)


def _extract_urls_from_payload(payload: object) -> list[str]:
    found: list[str] = []
    for value in _walk_values(payload):
        if value.startswith("http://") or value.startswith("https://"):
            found.append(value)
    dedup: list[str] = []
    seen: set[str] = set()
    for url in found:
        if url in seen:
            continue
        dedup.append(url)
        seen.add(url)
    return dedup


def _walk_values(value: object) -> list[str]:
    if isinstance(value, str):
        return [value]
    if isinstance(value, list):
        out: list[str] = []
        for item in value:
            out.extend(_walk_values(item))
        return out
    if isinstance(value, dict):
        out: list[str] = []
        for item in value.values():
            out.extend(_walk_values(item))
        return out
    return []


def _best_title(payload: dict) -> str:
    for key in ("title", "name", "listingName", "nickname"):
        value = payload.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()[:220]
    return "Guesty listing"


def _best_location(payload: dict) -> str:
    for key in ("city", "location", "address", "market"):
        value = payload.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()[:120]
        if isinstance(value, dict):
            city = value.get("city")
            if isinstance(city, str) and city.strip():
                return city.strip()[:120]
    return ""


class ApiHandler(BaseHTTPRequestHandler):
    crawler = build_crawler()

    def do_GET(self) -> None:
        if self.path == "/health":
            self._send_json(HTTPStatus.OK, {"status": "ok"})
            return
        self._send_json(HTTPStatus.NOT_FOUND, {"error": "not found"})

    def do_POST(self) -> None:
        if self.path not in {"/api/v1/crawl", "/api/v1/airbnb/search", "/api/v1/webhooks/guesty"}:
            self._send_json(HTTPStatus.NOT_FOUND, {"error": "not found"})
            return
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length).decode("utf-8", errors="replace")
        try:
            payload = json.loads(raw)
        except json.JSONDecodeError:
            self._send_json(HTTPStatus.BAD_REQUEST, {"error": "invalid json"})
            return
        if self.path == "/api/v1/crawl":
            status, body = handle_search_payload(payload, self.crawler)
            self._send_json(status, body)
            return
        if self.path == "/api/v1/airbnb/search":
            status, body = handle_airbnb_search_payload(payload, self.crawler)
            self._send_json(status, body)
            return
        if not _verify_guesty_signature(raw, self.headers.get("X-Guesty-Signature", "")):
            self._send_json(HTTPStatus.UNAUTHORIZED, {"error": "invalid webhook signature"})
            return
        status, body = handle_guesty_webhook(payload, self.crawler.store, self.headers.get("X-Guesty-Event", ""))
        self._send_json(status, body)

    def log_message(self, format: str, *args) -> None:
        return

    def _send_json(self, status: int, payload: dict) -> None:
        encoded = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)


def run() -> None:
    host = os.getenv("CRAWLER_HOST", "0.0.0.0")
    port = int(os.getenv("CRAWLER_PORT", "8080"))
    server = ThreadingHTTPServer((host, port), ApiHandler)
    server.serve_forever()


if __name__ == "__main__":
    run()
