from __future__ import annotations

import re
from html.parser import HTMLParser
from urllib.parse import urljoin, urlparse, urlunparse

BOOKING_KEYWORDS = {
    "book",
    "booking",
    "reserve",
    "reservation",
    "availability",
    "stayz",
    "airbnb",
    "vrbo",
    "expedia",
    "tripadvisor",
    "accommodation",
    "holiday rental",
}

COMMON_BOOKING_HOST_HINTS = {
    "airbnb.",
    "booking.",
    "stayz.",
    "vrbo.",
    "expedia.",
    "tripadvisor.",
    "agoda.",
    "wotif.",
    "homesandvillas.",
}


class LinkParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.links: list[tuple[str, str]] = []
        self._current_href: str | None = None
        self._text_parts: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag != "a":
            return
        href = ""
        for key, value in attrs:
            if key == "href" and value:
                href = value
                break
        if href:
            self._current_href = href
            self._text_parts = []

    def handle_data(self, data: str) -> None:
        if self._current_href is not None:
            self._text_parts.append(data)

    def handle_endtag(self, tag: str) -> None:
        if tag == "a" and self._current_href is not None:
            text = " ".join(part.strip() for part in self._text_parts if part.strip())
            self.links.append((self._current_href, text))
            self._current_href = None
            self._text_parts = []


def extract_links(html: str, base_url: str) -> list[tuple[str, str]]:
    parser = LinkParser()
    parser.feed(html)
    out: list[tuple[str, str]] = []
    for href, text in parser.links:
        absolute = urljoin(base_url, href)
        parsed = urlparse(absolute)
        if parsed.scheme not in {"http", "https"}:
            continue
        out.append((normalize_url(absolute), text))
    return out


def normalize_url(url: str) -> str:
    parsed = urlparse(url)
    cleaned = parsed._replace(fragment="")
    netloc = cleaned.netloc.lower()
    if netloc.startswith("www."):
        netloc = netloc[4:]
    path = re.sub(r"/+", "/", cleaned.path or "/")
    if path != "/":
        path = path.rstrip("/")
    return urlunparse((cleaned.scheme.lower(), netloc, path, "", cleaned.query, ""))


def is_likely_booking_url(url: str, anchor_text: str = "") -> bool:
    low_url = url.lower()
    low_text = anchor_text.lower()
    if any(host in low_url for host in COMMON_BOOKING_HOST_HINTS):
        return True
    if any(word in low_url for word in ("/book", "booking", "reserve", "availability", "rent")):
        return True
    return any(keyword in low_text for keyword in BOOKING_KEYWORDS)


def tokenize(text: str) -> list[str]:
    return [t for t in re.findall(r"[a-z0-9]+", text.lower()) if len(t) > 1]


def compute_relevance(title: str, snippet: str, terms: list[str], url: str) -> tuple[float, list[str]]:
    corpus = f"{title} {snippet} {url}".lower()
    matched: list[str] = []
    score = 0.0
    for term in terms:
        if term and term in corpus:
            matched.append(term)
            score += 1.0
    if is_likely_booking_url(url):
        score += 2.5
    return score, matched
