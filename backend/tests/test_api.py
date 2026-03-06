import unittest

from stays_crawler.models import CrawlResponse
from stays_crawler.server import handle_search_payload


class FakeCrawler:
    def crawl(self, request):
        return CrawlResponse(query="byron", total=0, results=[])


class TestApi(unittest.TestCase):
    def test_rejects_missing_location(self):
        status, body = handle_search_payload({}, crawler=FakeCrawler())
        self.assertEqual(status, 400)
        self.assertIn("location", body["error"])

    def test_accepts_valid_payload(self):
        status, body = handle_search_payload({"location": "Byron Bay"}, crawler=FakeCrawler())
        self.assertEqual(status, 200)
        self.assertEqual(body["query"], "byron")


if __name__ == "__main__":
    unittest.main()
