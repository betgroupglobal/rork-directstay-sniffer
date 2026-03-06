import unittest

from stays_crawler.models import CrawlRequest
from stays_crawler.sources.airbnb_provider import AirbnbProviderSource


class TestAirbnbProviderSource(unittest.TestCase):
    def test_searchapi_maps_and_filters_listing_urls(self):
        source = AirbnbProviderSource(provider="searchapi", api_key="token")

        def fake_request(method, url, headers, body=None):
            self.assertEqual(method, "GET")
            self.assertIn("engine=airbnb", url)
            self.assertIn("q=Byron+Bay", url)
            self.assertIn("api_key=token", url)
            return {
                "properties": [
                    {"title": "Byron Hideout", "booking_link": "https://airbnb.com/rooms/123456"},
                    {"title": "Search page", "link": "https://airbnb.com/s/Byron-Bay/homes"},
                    {"title": "Byron Loft", "url": "https://airbnb.com/rooms/777888"},
                ]
            }

        source._request_json = fake_request
        hits = source.discover(CrawlRequest(location="Byron Bay", bedrooms=2, bathrooms=1, guests=4))
        urls = [hit.url for hit in hits]
        self.assertEqual(len(urls), 2)
        self.assertIn("https://airbnb.com/rooms/123456", urls)
        self.assertIn("https://airbnb.com/rooms/777888", urls)

    def test_airroi_maps_listing_ids_to_airbnb_room_urls(self):
        source = AirbnbProviderSource(provider="airroi", api_key="key")

        def fake_request(method, url, headers, body=None):
            self.assertEqual(method, "POST")
            self.assertEqual(url, "https://api.airroi.com/listings/search/market")
            self.assertEqual(headers["X-API-KEY"], "key")
            return {
                "results": [
                    {"listing_info": {"listing_id": 12345, "listing_name": "A"}},
                    {"listing_info": {"listing_id": 67890, "listing_name": "B"}},
                ]
            }

        source._request_json = fake_request
        hits = source.discover(CrawlRequest(location="Melbourne", max_results=10))
        self.assertEqual([hit.url for hit in hits], ["https://airbnb.com/rooms/12345", "https://airbnb.com/rooms/67890"])


if __name__ == "__main__":
    unittest.main()
