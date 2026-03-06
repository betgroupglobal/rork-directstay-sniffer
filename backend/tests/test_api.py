import unittest
from unittest.mock import patch

from stays_crawler.models import CrawlResponse
from stays_crawler.server import handle_airbnb_search_payload, handle_search_payload


class FakeCrawler:
    airbnb_provider = "searchapi"
    airbnb_api_key = "token"

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

    @patch("stays_crawler.sources.airbnb_provider.AirbnbProviderSource._request_json")
    def test_airbnb_search_handler(self, mock_request_json):
        mock_request_json.return_value = {
            "properties": [
                {"title": "Byron", "booking_link": "https://airbnb.com/rooms/123"}
            ]
        }
        crawler = FakeCrawler()
        status, body = handle_airbnb_search_payload({"location": "Byron Bay", "max_results": 2}, crawler=crawler)
        self.assertEqual(status, 200)
        self.assertEqual(body["source"], "searchapi")
        self.assertEqual(body["total"], 1)
        self.assertEqual(body["results"][0]["url"], "https://airbnb.com/rooms/123")


if __name__ == "__main__":
    unittest.main()
