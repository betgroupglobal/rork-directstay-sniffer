import os
import tempfile
import unittest

from stays_crawler.server import handle_guesty_webhook
from stays_crawler.storage import CrawlStore


class TestGuestyWebhook(unittest.TestCase):
    def test_saves_direct_property_urls(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            store = CrawlStore(os.path.join(tmpdir, "crawler.db"))
            payload = {
                "title": "Melbourne Apt",
                "city": "Melbourne",
                "airbnbUrl": "https://airbnb.com/rooms/44556677",
                "searchUrl": "https://airbnb.com/s/Melbourne/homes",
            }
            status, body = handle_guesty_webhook(payload, store, event_type="listing.updated")
            self.assertEqual(status, 200)
            self.assertEqual(body["saved"], 1)
            seeds = store.list_external_seeds(source="guesty", location="Melbourne", limit=10)
            self.assertEqual(len(seeds), 1)
            self.assertEqual(seeds[0].url, "https://airbnb.com/rooms/44556677")


if __name__ == "__main__":
    unittest.main()
