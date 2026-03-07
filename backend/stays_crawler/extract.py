from __future__ import annotations

import re
from datetime import datetime
from html import unescape
from html.parser import HTMLParser
from urllib.parse import parse_qs, urljoin, urlparse, urlunparse

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

OTA_HOST_HINTS = tuple(COMMON_BOOKING_HOST_HINTS)

NON_PROPERTY_PATH_HINTS = (
    "/search",
    "/searchresults",
    "/hotel-search",
    "/homes",
    "/stays",
    "/results",
    "/discover",
    "/destinations",
)


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


def is_direct_property_url(url: str) -> bool:
    parsed = urlparse(url)
    host = parsed.netloc.lower()
    path = parsed.path.lower()
    query = parse_qs(parsed.query)
    if not host or not path:
        return False
    if any(hint in path for hint in NON_PROPERTY_PATH_HINTS):
        return False
    if "airbnb." in host:
        return "/rooms/" in path
    if "booking." in host:
        return "/hotel/" in path
    if "vrbo." in host or "stayz." in host:
        return "/p" in path or "/holiday-rental/" in path or bool(re.search(r"/\d{5,}", path))
    if "expedia." in host:
        return "hotel-information" in path
    if any(token in path for token in ("/property/", "/listing/", "/accommodation/", "/book/", "/reserve/")):
        return True
    if "id" in query and query["id"]:
        return True
    return bool(re.search(r"/\d{5,}", path))


def is_ota_url(url: str) -> bool:
    host = urlparse(url).netloc.lower()
    return any(hint in host for hint in OTA_HOST_HINTS)


def extract_primary_image_details(html: str) -> tuple[str | None, str | None]:
    image_url_match = re.search(
        r'<meta[^>]+(?:property|name)=["\'](?:og:image|twitter:image)["\'][^>]*content=["\']([^"\']+)["\']',
        html,
        re.IGNORECASE,
    )
    image_url = image_url_match.group(1).strip() if image_url_match else None

    image_desc_match = re.search(
        r'<meta[^>]+(?:property|name)=["\'](?:og:image:alt|twitter:image:alt|description|og:description)["\'][^>]*content=["\']([^"\']+)["\']',
        html,
        re.IGNORECASE,
    )
    image_desc = image_desc_match.group(1).strip() if image_desc_match else None

    if not image_desc:
        img_match = re.search(r"<img[^>]+>", html, re.IGNORECASE)
        if img_match:
            tag = img_match.group(0)
            alt_match = re.search(r'alt=["\']([^"\']+)["\']', tag, re.IGNORECASE)
            if alt_match:
                image_desc = alt_match.group(1).strip()

    if image_desc:
        image_desc = unescape(re.sub(r"\s+", " ", image_desc))[:220]

    return image_url, image_desc


def extract_estimated_cost(text: str, check_in: str | None, check_out: str | None) -> str | None:
    candidates = re.findall(r"(?:AUD|USD|CAD|NZD|EUR|GBP|\$|€|£)\s?\d{2,5}(?:,\d{3})*(?:\.\d{2})?", text, re.IGNORECASE)
    if not candidates:
        return None

    nightly = candidates[0].upper().replace("USD", "$ ").replace("AUD", "$ ").replace("CAD", "$ ").replace("NZD", "$ ").replace("EUR", "€ ").replace("GBP", "£ ")
    nightly = re.sub(r"\s+", " ", nightly).strip()

    if not check_in or not check_out:
        return f"{nightly} per night"

    try:
        start = datetime.strptime(check_in, "%Y-%m-%d")
        end = datetime.strptime(check_out, "%Y-%m-%d")
    except ValueError:
        return f"{nightly} per night"

    nights = (end - start).days
    if nights <= 0:
        return f"{nightly} per night"

    number_match = re.search(r"\d{2,5}(?:,\d{3})*(?:\.\d{2})?", nightly)
    if not number_match:
        return f"{nightly} per night"
    amount = float(number_match.group(0).replace(",", ""))
    total = amount * nights
    currency = nightly[: number_match.start()].strip() or "$"
    if total.is_integer():
        total_str = f"{int(total):,}"
    else:
        total_str = f"{total:,.2f}"
    return f"{currency} {total_str} for {nights} night{'s' if nights != 1 else ''}"


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
