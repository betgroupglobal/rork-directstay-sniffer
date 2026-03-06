import os
import tempfile
import unittest

from stays_crawler.crawler import StaysCrawler
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
            "https://example.com/search": '<html><a href="https://host.com/book/blue-house">Book now</a></html>'
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
            req = CrawlRequest(location="Byron Bay", bedrooms=2, bathrooms=1, max_results=10)
            result = crawler.crawl(req)
            self.assertEqual(result.total, 1)
            self.assertEqual(result.results[0].booking_url, "https://host.com/book/blue-house")

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
            self.assertEqual(fetcher.calls, 1)


if __name__ == "__main__":
    unittest.main()
