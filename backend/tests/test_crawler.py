import os
import tempfile
import unittest

from stays_crawler.crawler import StaysCrawler
from stays_crawler.extract import compute_relevance
from stays_crawler.fetcher import FetchedPage
from stays_crawler.models import CrawlRequest, SeedHit
from stays_crawler.sources.base import SearchSource
from stays_crawler.storage import CrawlStore


class FakeFetcher:
    def __init__(self, pages):
        self.pages = pages
        self.calls = 0

    def fetch(self, url):
        self.calls += 1
        page = self.pages.get(url)
        if not page:
            return None
        return FetchedPage(url=url, status=200, content_type="text/html", text=page)


class FakeSource(SearchSource):
    name = "fake"

    def __init__(self, url):
        self.url = url

    def discover(self, request):
        return [SeedHit(url=self.url, source=self.name, title="Byron stay", snippet="")]


class TestCrawler(unittest.TestCase):
    def test_discovers_booking_links(self):
        pages = {
            "https://example.com/search": '<html><body><a href="https://host.com/book/blue-house">Book now</a></body></html>',
            "https://host.com/book/blue-house": '<html><head><title>Blue House</title><meta property="og:image" content="https://img.example.com/house.jpg"><meta property="og:description" content="Oceanfront villa with private deck"></head><body>$250 per night</body></html>',
        }
        with tempfile.TemporaryDirectory() as tmpdir:
            db_path = os.path.join(tmpdir, "crawler.db")
            crawler = StaysCrawler(
                fetcher=FakeFetcher(pages),
                default_depth=1,
                default_pages_per_source=5,
                store=CrawlStore(db_path),
                cache_ttl_seconds=600,
            )
            crawler._build_sources = lambda: [FakeSource("https://example.com/search")]
            req = CrawlRequest(location="Byron Bay", bedrooms=2, bathrooms=1, max_results=10, check_in="2026-04-01", check_out="2026-04-04")
            result = crawler.crawl(req)
            self.assertEqual(result.total, 1)
            self.assertEqual(result.results[0].booking_url, "https://host.com/book/blue-house")
            self.assertEqual(result.results[0].title, "Blue House")
            self.assertEqual(result.results[0].snippet, "Oceanfront villa with private deck")
            self.assertEqual(result.results[0].image_url, "https://img.example.com/house.jpg")
            self.assertEqual(result.results[0].image_description, "Oceanfront villa with private deck")
            self.assertEqual(result.results[0].estimated_cost, "$ 750 for 3 nights")

    def test_uses_cache_between_calls(self):
        pages = {
            "https://example.com/search": '<html><a href="https://host.com/book/blue-house">Book now</a></html>'
        }
        fetcher = FakeFetcher(pages)
        with tempfile.TemporaryDirectory() as tmpdir:
            db_path = os.path.join(tmpdir, "crawler.db")
            crawler = StaysCrawler(
                fetcher=fetcher,
                default_depth=1,
                default_pages_per_source=5,
                store=CrawlStore(db_path),
                cache_ttl_seconds=3600,
            )
            crawler._build_sources = lambda: [FakeSource("https://example.com/search")]
            req = CrawlRequest(location="Byron Bay", max_results=10)
            first = crawler.crawl(req)
            second = crawler.crawl(req)
            self.assertEqual(first.total, second.total)
            self.assertEqual(fetcher.calls, 2)

    def test_does_not_return_search_results_pages(self):
        pages = {
            "https://example.com/search": '<html><a href="https://airbnb.com/s/Byron+Bay/homes">Homes</a><a href="https://airbnb.com/rooms/123456">Room</a></html>'
        }
        with tempfile.TemporaryDirectory() as tmpdir:
            db_path = os.path.join(tmpdir, "crawler.db")
            crawler = StaysCrawler(
                fetcher=FakeFetcher(pages),
                default_depth=1,
                default_pages_per_source=5,
                store=CrawlStore(db_path),
                cache_ttl_seconds=600,
            )
            crawler._build_sources = lambda: [FakeSource("https://example.com/search")]
            req = CrawlRequest(location="Byron Bay", max_results=10)
            result = crawler.crawl(req)
            self.assertEqual(result.total, 1)
            self.assertEqual(result.results[0].booking_url, "https://airbnb.com/rooms/123456")

    def test_exclude_ota_filters_airbnb_and_booking_links(self):
        pages = {
            "https://example.com/search": '<html><a href="https://airbnb.com/rooms/123456">Airbnb</a><a href="https://booking.com/hotel/au/demo.en-gb.html">Booking</a><a href="https://host.com/book/blue-house">Direct</a></html>'
        }
        with tempfile.TemporaryDirectory() as tmpdir:
            db_path = os.path.join(tmpdir, "crawler.db")
            crawler = StaysCrawler(
                fetcher=FakeFetcher(pages),
                default_depth=1,
                default_pages_per_source=5,
                store=CrawlStore(db_path),
                cache_ttl_seconds=600,
            )
            crawler._build_sources = lambda: [FakeSource("https://example.com/search")]
            req = CrawlRequest(location="Byron Bay", max_results=10, exclude_ota=True)
            result = crawler.crawl(req)
            self.assertEqual(result.total, 1)
            self.assertEqual(result.results[0].booking_url, "https://host.com/book/blue-house")

    def test_compute_relevance_avoids_partial_substring_matches(self):
        score, matched = compute_relevance(
            title="Coastal carpet villa",
            snippet="Sunny deck with ocean view",
            terms=["pet"],
            url="https://example.com/listing/coastal-villa",
        )
        self.assertEqual(score, 0.0)
        self.assertEqual(matched, [])

    def test_compute_relevance_matches_phrases_once(self):
        score, matched = compute_relevance(
            title="Owner direct holiday rental in Byron Bay",
            snippet="Book direct for best rate",
            terms=["owner direct", "owner direct", "BYRON", "byron"],
            url="https://host.com/book/blue-house",
        )
        self.assertEqual(score, 4.5)
        self.assertEqual(matched, ["owner direct", "byron"])

    def test_build_terms_keeps_direct_hunter_phrases(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            db_path = os.path.join(tmpdir, "crawler.db")
            crawler = StaysCrawler(
                fetcher=FakeFetcher({}),
                default_depth=1,
                default_pages_per_source=5,
                store=CrawlStore(db_path),
                cache_ttl_seconds=600,
            )
            terms = crawler._build_terms(CrawlRequest(location="Byron Bay", direct_hunter=True, max_results=5))
            self.assertIn("byron bay", terms)
            self.assertIn("owner direct", terms)
            self.assertIn("book direct", terms)
            self.assertIn("byron", terms)


if __name__ == "__main__":
    unittest.main()
