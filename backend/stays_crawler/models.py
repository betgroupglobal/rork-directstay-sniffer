from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass
class CrawlRequest:
    location: str
    check_in: str | None = None
    check_out: str | None = None
    guests: int | None = None
    bedrooms: int | None = None
    bathrooms: int | None = None
    pet_friendly: bool | None = None
    whole_home: bool | None = None
    exclude_ota: bool | None = None
    max_results: int = 30
    crawl_depth: int | None = None
    max_pages_per_source: int | None = None
    forum_search_templates: list[str] = field(default_factory=list)
    social_search_templates: list[str] = field(default_factory=list)

    @classmethod
    def from_payload(cls, payload: dict[str, Any]) -> "CrawlRequest":
        location = str(payload.get("location", "")).strip()
        if not location:
            raise ValueError("location is required")
        return cls(
            location=location,
            check_in=_as_optional_str(payload.get("check_in")),
            check_out=_as_optional_str(payload.get("check_out")),
            guests=_as_optional_int(payload.get("guests")),
            bedrooms=_as_optional_int(payload.get("bedrooms")),
            bathrooms=_as_optional_int(payload.get("bathrooms")),
            pet_friendly=_as_optional_bool(payload.get("pet_friendly")),
            whole_home=_as_optional_bool(payload.get("whole_home")),
            exclude_ota=_as_optional_bool(payload.get("exclude_ota")),
            max_results=max(1, min(int(payload.get("max_results", 30)), 200)),
            crawl_depth=_as_optional_int(payload.get("crawl_depth")),
            max_pages_per_source=_as_optional_int(payload.get("max_pages_per_source")),
            forum_search_templates=_as_str_list(payload.get("forum_search_templates")),
            social_search_templates=_as_str_list(payload.get("social_search_templates")),
        )


@dataclass
class SeedHit:
    url: str
    source: str
    title: str = ""
    snippet: str = ""


@dataclass
class BookingHit:
    booking_url: str
    source: str
    discovered_on: str
    title: str
    snippet: str
    score: float
    matched_terms: list[str] = field(default_factory=list)
    image_url: str | None = None
    image_description: str | None = None
    estimated_cost: str | None = None


@dataclass
class CrawlResponse:
    query: str
    total: int
    results: list[BookingHit]

    def to_dict(self) -> dict[str, Any]:
        return {
            "query": self.query,
            "total": self.total,
            "results": [
                {
                    "booking_url": item.booking_url,
                    "source": item.source,
                    "discovered_on": item.discovered_on,
                    "title": item.title,
                    "snippet": item.snippet,
                    "score": round(item.score, 3),
                    "matched_terms": item.matched_terms,
                    "image_url": item.image_url,
                    "image_description": item.image_description,
                    "estimated_cost": item.estimated_cost,
                }
                for item in self.results
            ],
        }


def _as_optional_int(value: Any) -> int | None:
    if value is None or value == "":
        return None
    return int(value)


def _as_optional_bool(value: Any) -> bool | None:
    if value is None or value == "":
        return None
    if isinstance(value, bool):
        return value
    text = str(value).strip().lower()
    if text in {"1", "true", "yes", "y"}:
        return True
    if text in {"0", "false", "no", "n"}:
        return False
    raise ValueError(f"invalid boolean value: {value}")


def _as_optional_str(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    return text if text else None


def _as_str_list(value: Any) -> list[str]:
    if value is None:
        return []
    if not isinstance(value, list):
        raise ValueError("expected list")
    out: list[str] = []
    for item in value:
        text = str(item).strip()
        if text:
            out.append(text)
    return out
