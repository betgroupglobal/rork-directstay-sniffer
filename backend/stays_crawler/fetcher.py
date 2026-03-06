from __future__ import annotations

import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from urllib.parse import urlparse
from urllib.robotparser import RobotFileParser


@dataclass
class FetchedPage:
    url: str
    status: int
    content_type: str
    text: str


class HttpFetcher:
    def __init__(self, user_agent: str, timeout_seconds: int = 8, min_delay_seconds: float = 0.5) -> None:
        self.user_agent = user_agent
        self.timeout_seconds = timeout_seconds
        self.min_delay_seconds = min_delay_seconds
        self._robots_cache: dict[str, RobotFileParser] = {}
        self._last_hit_by_host: dict[str, float] = {}

    def fetch(self, url: str) -> FetchedPage | None:
        if not self._allowed_by_robots(url):
            return None
        self._throttle(url)
        request = urllib.request.Request(url, headers={"User-Agent": self.user_agent, "Accept": "text/html,application/json"})
        try:
            with urllib.request.urlopen(request, timeout=self.timeout_seconds) as response:
                content_type = response.headers.get("Content-Type", "")
                raw = response.read()
                text = raw.decode("utf-8", errors="replace")
                return FetchedPage(url=response.geturl(), status=response.status, content_type=content_type, text=text)
        except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError, ValueError):
            return None

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
