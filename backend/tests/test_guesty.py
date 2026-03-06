import os
import tempfile
import unittest

from stays_crawler.models import CrawlRequest
from stays_crawler.sources.guesty import GuestySource
from stays_crawler.storage import CrawlStore


class TestGuestySource(unittest.TestCase):
    def test_reads_seeds_from_webhook_store_without_credentials(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            store = CrawlStore(os.path.join(tmpdir, "crawler.db"))
            store.upsert_external_seed(
                source="guesty",
                url="https://airbnb.com/rooms/123456",
                title="Guesty listing",
                snippet="event",
                location_hint="Melbourne",
            )
            source = GuestySource(store=store, client_id="", client_secret="")
            req = CrawlRequest(location="Melbourne", max_results=10)
            hits = source.discover(req)
            self.assertEqual(len(hits), 1)
            self.assertEqual(hits[0].url, "https://airbnb.com/rooms/123456")

    def test_fetches_and_filters_direct_property_urls_from_api(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            store = CrawlStore(os.path.join(tmpdir, "crawler.db"))
            source = GuestySource(store=store, client_id="id", client_secret="secret")

            def fake_request(method, url, headers, body=None):
                if url.endswith("/oauth2/token"):
                    return {"access_token": "abc", "expires_in": 86400}
                return {
                    "results": [
                        {
                            "title": "Melbourne CBD Loft",
                            "city": "Melbourne",
                            "airbnbListingUrl": "https://airbnb.com/rooms/99887766",
                            "bookingComListingUrl": "https://booking.com/searchresults.html?ss=Melbourne",
                        }
                    ]
                }

            source._request_json = fake_request
            req = CrawlRequest(location="Melbourne", max_results=10)
            hits = source.discover(req)
            self.assertEqual(len(hits), 1)
            self.assertEqual(hits[0].url, "https://airbnb.com/rooms/99887766")


if __name__ == "__main__":
    unittest.main()
