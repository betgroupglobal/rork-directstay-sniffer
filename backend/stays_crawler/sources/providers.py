from __future__ import annotations

from urllib.parse import quote_plus, urlencode

from stays_crawler.models import CrawlRequest, SeedHit
from stays_crawler.sources.base import SearchSource


class ProviderSeedSource(SearchSource):
    name = "providers"

    def discover(self, request: CrawlRequest) -> list[SeedHit]:
        location = quote_plus(request.location)
        hits: list[SeedHit] = []
        hits.extend(self._stayz(location, request))
        hits.extend(self._vrbo(location, request))
        hits.extend(self._airbnb(location, request))
        hits.extend(self._booking(location, request))
        hits.extend(self._expedia(location, request))
        return hits

    def _stayz(self, location: str, request: CrawlRequest) -> list[SeedHit]:
        params = {"destination": request.location}
        if request.guests:
            params["adultsCount"] = request.guests
        return [
            SeedHit(
                url=f"https://www.stayz.com.au/search?{urlencode(params)}",
                source=self.name,
                title=f"Stayz {request.location}",
                snippet="",
            )
        ]

    def _vrbo(self, location: str, request: CrawlRequest) -> list[SeedHit]:
        params = {"destination": request.location}
        if request.guests:
            params["adultsCount"] = request.guests
        return [
            SeedHit(
                url=f"https://www.vrbo.com/search?{urlencode(params)}",
                source=self.name,
                title=f"Vrbo {request.location}",
                snippet="",
            )
        ]

    def _airbnb(self, location: str, request: CrawlRequest) -> list[SeedHit]:
        params = {"query": request.location}
        if request.check_in:
            params["checkin"] = request.check_in
        if request.check_out:
            params["checkout"] = request.check_out
        if request.guests:
            params["adults"] = request.guests
        return [
            SeedHit(
                url=f"https://www.airbnb.com/s/{location}/homes?{urlencode(params)}",
                source=self.name,
                title=f"Airbnb {request.location}",
                snippet="",
            )
        ]

    def _booking(self, location: str, request: CrawlRequest) -> list[SeedHit]:
        params = {"ss": request.location}
        if request.check_in:
            params["checkin"] = request.check_in
        if request.check_out:
            params["checkout"] = request.check_out
        if request.guests:
            params["group_adults"] = request.guests
        return [
            SeedHit(
                url=f"https://www.booking.com/searchresults.html?{urlencode(params)}",
                source=self.name,
                title=f"Booking {request.location}",
                snippet="",
            )
        ]

    def _expedia(self, location: str, request: CrawlRequest) -> list[SeedHit]:
        params = {"destination": request.location}
        if request.check_in:
            params["startDate"] = request.check_in
        if request.check_out:
            params["endDate"] = request.check_out
        return [
            SeedHit(
                url=f"https://www.expedia.com/Hotel-Search?{urlencode(params)}",
                source=self.name,
                title=f"Expedia {request.location}",
                snippet="",
            )
        ]
