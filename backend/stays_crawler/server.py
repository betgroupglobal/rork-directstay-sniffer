from __future__ import annotations

import json
import os
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from stays_crawler.crawler import StaysCrawler
from stays_crawler.fetcher import HttpFetcher
from stays_crawler.models import CrawlRequest
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
    return StaysCrawler(fetcher=fetcher, default_depth=depth, default_pages_per_source=pages, store=store, cache_ttl_seconds=cache_ttl)


def handle_search_payload(payload: dict, crawler: StaysCrawler | None = None) -> tuple[int, dict]:
    service = crawler or build_crawler()
    try:
        req = CrawlRequest.from_payload(payload)
    except (TypeError, ValueError) as exc:
        return HTTPStatus.BAD_REQUEST, {"error": str(exc)}
    response = service.crawl(req)
    return HTTPStatus.OK, response.to_dict()


class ApiHandler(BaseHTTPRequestHandler):
    crawler = build_crawler()

    def do_GET(self) -> None:
        if self.path == "/health":
            self._send_json(HTTPStatus.OK, {"status": "ok"})
            return
        self._send_json(HTTPStatus.NOT_FOUND, {"error": "not found"})

    def do_POST(self) -> None:
        if self.path != "/api/v1/crawl":
            self._send_json(HTTPStatus.NOT_FOUND, {"error": "not found"})
            return
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length).decode("utf-8", errors="replace")
        try:
            payload = json.loads(raw)
        except json.JSONDecodeError:
            self._send_json(HTTPStatus.BAD_REQUEST, {"error": "invalid json"})
            return
        status, body = handle_search_payload(payload, self.crawler)
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
