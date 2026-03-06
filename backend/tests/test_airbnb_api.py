import unittest

from stays_crawler.models import CrawlRequest
from stays_crawler.sources.airbnb_api import AirbnbApiSource


class TestAirbnbApiSource(unittest.TestCase):
    def test_returns_empty_without_api_base(self):
        source = AirbnbApiSource(api_base="", api_key="")
        hits = source.discover(CrawlRequest(location="Byron Bay"))
        self.assertEqual(hits, [])

    def test_maps_and_filters_listing_urls(self):
        source = AirbnbApiSource(api_base="https://api.example.test", api_key="token")

        def fake_request(url, headers):
            self.assertIn("location=Byron+Bay", url)
            self.assertEqual(headers["Authorization"], "Bearer token")
            return {
                "results": [
                    {
                        "title": "Byron Hideout",
                        "url": "https://airbnb.com/rooms/123456",
                    },
                    {
                        "title": "Search page",
                        "url": "https://airbnb.com/s/Byron-Bay/homes",
                    },
                    {
                        "name": "Byron Loft",
                        "listing": {"deeplink": "https://airbnb.com/rooms/777888"},
                    },
                ]
            }

        source._request_json = fake_request
        hits = source.discover(CrawlRequest(location="Byron Bay", bedrooms=2, bathrooms=1, guests=4))
        urls = [hit.url for hit in hits]
        self.assertEqual(len(urls), 2)
        self.assertIn("https://airbnb.com/rooms/123456", urls)
        self.assertIn("https://airbnb.com/rooms/777888", urls)


if __name__ == "__main__":
    unittest.main()
