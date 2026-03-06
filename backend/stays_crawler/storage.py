from __future__ import annotations

import hashlib
import json
import sqlite3
import time
from dataclasses import asdict, dataclass

from stays_crawler.models import BookingHit, CrawlRequest, CrawlResponse, SeedHit


@dataclass
class QueueItem:
    item_id: int
    request_key: str
    url: str
    source: str
    title: str
    snippet: str
    depth: int


class CrawlStore:
    def __init__(self, db_path: str) -> None:
        self.db_path = db_path
        self._init_db()

    def upsert_external_seed(self, source: str, url: str, title: str, snippet: str, location_hint: str = "") -> None:
        with sqlite3.connect(self.db_path) as conn:
            conn.execute(
                """
                INSERT INTO external_seeds(source, url, title, snippet, location_hint, created_at)
                VALUES(?, ?, ?, ?, ?, ?)
                ON CONFLICT(source, url) DO UPDATE SET
                    title = excluded.title,
                    snippet = excluded.snippet,
                    location_hint = excluded.location_hint,
                    created_at = excluded.created_at
                """,
                (source, url, title[:220], snippet[:500], location_hint[:120], time.time()),
            )
            conn.commit()

    def list_external_seeds(self, source: str, location: str, limit: int = 100) -> list[SeedHit]:
        location_like = f"%{location.lower()}%"
        with sqlite3.connect(self.db_path) as conn:
            rows = conn.execute(
                """
                SELECT url, source, title, snippet
                FROM external_seeds
                WHERE source = ?
                  AND (LOWER(location_hint) LIKE ? OR LOWER(title) LIKE ? OR LOWER(snippet) LIKE ?)
                ORDER BY created_at DESC
                LIMIT ?
                """,
                (source, location_like, location_like, location_like, max(1, limit)),
            ).fetchall()
        return [SeedHit(url=str(row[0]), source=str(row[1]), title=str(row[2]), snippet=str(row[3])) for row in rows]

    def make_request_key(self, request: CrawlRequest) -> str:
        payload = asdict(request)
        canonical = json.dumps(payload, sort_keys=True, separators=(",", ":"))
        return hashlib.sha256(canonical.encode("utf-8")).hexdigest()

    def get_cached_response(self, request_key: str, ttl_seconds: int) -> CrawlResponse | None:
        with sqlite3.connect(self.db_path) as conn:
            row = conn.execute(
                "SELECT response_json, created_at FROM result_cache WHERE request_key = ?",
                (request_key,),
            ).fetchone()
        if row is None:
            return None
        response_json, created_at = row
        if (time.time() - float(created_at)) > max(0, ttl_seconds):
            return None
        payload = json.loads(response_json)
        return _response_from_dict(payload)

    def set_cached_response(self, request_key: str, response: CrawlResponse) -> None:
        payload = response.to_dict()
        with sqlite3.connect(self.db_path) as conn:
            conn.execute(
                """
                INSERT INTO result_cache(request_key, response_json, created_at)
                VALUES(?, ?, ?)
                ON CONFLICT(request_key) DO UPDATE SET
                    response_json = excluded.response_json,
                    created_at = excluded.created_at
                """,
                (request_key, json.dumps(payload), time.time()),
            )
            conn.commit()

    def enqueue_seeds(self, request_key: str, seeds: list[SeedHit], depth: int = 0) -> None:
        with sqlite3.connect(self.db_path) as conn:
            for seed in seeds:
                conn.execute(
                    """
                    INSERT OR IGNORE INTO crawl_queue(request_key, url, source, title, snippet, depth, status, created_at)
                    VALUES(?, ?, ?, ?, ?, ?, 'pending', ?)
                    """,
                    (request_key, seed.url, seed.source, seed.title, seed.snippet, depth, time.time()),
                )
            conn.commit()

    def enqueue_links(self, request_key: str, links: list[tuple[str, str, str]], depth: int) -> None:
        with sqlite3.connect(self.db_path) as conn:
            for url, source, title in links:
                conn.execute(
                    """
                    INSERT OR IGNORE INTO crawl_queue(request_key, url, source, title, snippet, depth, status, created_at)
                    VALUES(?, ?, ?, ?, '', ?, 'pending', ?)
                    """,
                    (request_key, url, source, title[:220], depth, time.time()),
                )
            conn.commit()

    def pop_next_pending(self, request_key: str) -> QueueItem | None:
        with sqlite3.connect(self.db_path) as conn:
            row = conn.execute(
                """
                SELECT id, request_key, url, source, title, snippet, depth
                FROM crawl_queue
                WHERE request_key = ? AND status = 'pending'
                ORDER BY depth ASC, id ASC
                LIMIT 1
                """,
                (request_key,),
            ).fetchone()
            if row is None:
                return None
            conn.execute("UPDATE crawl_queue SET status = 'processing' WHERE id = ?", (row[0],))
            conn.commit()
        return QueueItem(
            item_id=int(row[0]),
            request_key=str(row[1]),
            url=str(row[2]),
            source=str(row[3]),
            title=str(row[4]),
            snippet=str(row[5]),
            depth=int(row[6]),
        )

    def mark_done(self, item_id: int) -> None:
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("UPDATE crawl_queue SET status = 'done' WHERE id = ?", (item_id,))
            conn.commit()

    def reset_processing(self, request_key: str) -> None:
        with sqlite3.connect(self.db_path) as conn:
            conn.execute(
                "UPDATE crawl_queue SET status = 'pending' WHERE request_key = ? AND status = 'processing'",
                (request_key,),
            )
            conn.commit()

    def _init_db(self) -> None:
        with sqlite3.connect(self.db_path) as conn:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS crawl_queue(
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    request_key TEXT NOT NULL,
                    url TEXT NOT NULL,
                    source TEXT NOT NULL,
                    title TEXT NOT NULL,
                    snippet TEXT NOT NULL,
                    depth INTEGER NOT NULL,
                    status TEXT NOT NULL,
                    created_at REAL NOT NULL,
                    UNIQUE(request_key, url, depth)
                )
                """
            )
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS result_cache(
                    request_key TEXT PRIMARY KEY,
                    response_json TEXT NOT NULL,
                    created_at REAL NOT NULL
                )
                """
            )
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS external_seeds(
                    source TEXT NOT NULL,
                    url TEXT NOT NULL,
                    title TEXT NOT NULL,
                    snippet TEXT NOT NULL,
                    location_hint TEXT NOT NULL,
                    created_at REAL NOT NULL,
                    PRIMARY KEY(source, url)
                )
                """
            )
            conn.commit()


def _response_from_dict(payload: dict) -> CrawlResponse:
    results: list[BookingHit] = []
    for item in payload.get("results", []):
        results.append(
            BookingHit(
                booking_url=str(item.get("booking_url", "")),
                source=str(item.get("source", "")),
                discovered_on=str(item.get("discovered_on", "")),
                title=str(item.get("title", "")),
                snippet=str(item.get("snippet", "")),
                score=float(item.get("score", 0.0)),
                matched_terms=[str(term) for term in item.get("matched_terms", [])],
            )
        )
    return CrawlResponse(query=str(payload.get("query", "")), total=int(payload.get("total", len(results))), results=results)
