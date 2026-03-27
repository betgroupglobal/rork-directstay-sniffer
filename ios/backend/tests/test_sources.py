import unittest

from stays_crawler.models import CrawlRequest
from stays_crawler.sources.providers import ProviderSeedSource


class TestProviderSources(unittest.TestCase):
    def test_provider_seed_urls_are_generated(self):
        source = ProviderSeedSource()
        req = CrawlRequest(location="Byron Bay", check_in="2026-04-01", check_out="2026-04-03", guests=2)
        hits = source.discover(req)
        urls = [hit.url for hit in hits]
        self.assertEqual(len(urls), 5)
        self.assertTrue(any("stayz" in url for url in urls))
        self.assertTrue(any("airbnb" in url for url in urls))
        self.assertTrue(any("booking.com" in url for url in urls))


if __name__ == "__main__":
    unittest.main()
