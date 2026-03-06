from __future__ import annotations

import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from itertools import cycle
from urllib.parse import urlparse
from urllib.robotparser import RobotFileParser


@dataclass
class FetchedPage:
    url: str
    status: int
    content_type: str
    text: str


class HttpFetcher:
    def __init__(
        self,
        user_agent: str,
        timeout_seconds: int = 8,
        min_delay_seconds: float = 0.5,
        retry_count: int = 2,
        retry_backoff_seconds: float = 0.5,
        user_agents: list[str] | None = None,
        proxies: list[str] | None = None,
    ) -> None:
        self.user_agent = user_agent
        self.timeout_seconds = timeout_seconds
        self.min_delay_seconds = min_delay_seconds
        self.retry_count = max(0, retry_count)
        self.retry_backoff_seconds = max(0.0, retry_backoff_seconds)
        self._robots_cache: dict[str, RobotFileParser] = {}
        self._last_hit_by_host: dict[str, float] = {}
        self._ua_cycle = cycle(user_agents or [user_agent])
        self._proxy_cycle = cycle(proxies or [""])

    def fetch(self, url: str) -> FetchedPage | None:
        if not self._allowed_by_robots(url):
            return None
        self._throttle(url)
        last_error: Exception | None = None
        for attempt in range(self.retry_count + 1):
            ua = next(self._ua_cycle)
            proxy = next(self._proxy_cycle)
            try:
                page = self._single_fetch(url, ua, proxy)
                if page is not None:
                    return page
            except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError, ValueError) as exc:
                last_error = exc
            if attempt < self.retry_count and self.retry_backoff_seconds > 0:
                time.sleep(self.retry_backoff_seconds * (attempt + 1))
        if last_error is not None:
            return None
        return None

    def _single_fetch(self, url: str, user_agent: str, proxy_url: str) -> FetchedPage | None:
        request = urllib.request.Request(url, headers={"User-Agent": user_agent, "Accept": "text/html,application/json"})
        if proxy_url:
            opener = urllib.request.build_opener(urllib.request.ProxyHandler({"http": proxy_url, "https": proxy_url}))
            with opener.open(request, timeout=self.timeout_seconds) as response:
                content_type = response.headers.get("Content-Type", "")
                raw = response.read()
                text = raw.decode("utf-8", errors="replace")
                return FetchedPage(url=response.geturl(), status=response.status, content_type=content_type, text=text)
        with urllib.request.urlopen(request, timeout=self.timeout_seconds) as response:
            content_type = response.headers.get("Content-Type", "")
            raw = response.read()
            text = raw.decode("utf-8", errors="replace")
            return FetchedPage(url=response.geturl(), status=response.status, content_type=content_type, text=text)

    def _allowed_by_robots(self, url: str) -> bool:
        parsed = urlparse(url)
        if parsed.scheme not in {"http", "https"} or not parsed.netloc:
            return False
        origin = f"{parsed.scheme}://{parsed.netloc}"
        parser = self._robots_cache.get(origin)
        if parser is None:
            parser = RobotFileParser()
            parser.set_url(f"{origin}/robots.txt")
            try:
                parser.read()
            except Exception:
                return True
            self._robots_cache[origin] = parser
        return parser.can_fetch(self.user_agent, url)

    def _throttle(self, url: str) -> None:
        host = urlparse(url).netloc.lower()
        now = time.monotonic()
        last = self._last_hit_by_host.get(host)
        if last is not None:
            delta = now - last
            if delta < self.min_delay_seconds:
                time.sleep(self.min_delay_seconds - delta)
        self._last_hit_by_host[host] = time.monotonic()
