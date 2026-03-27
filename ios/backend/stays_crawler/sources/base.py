from __future__ import annotations

from abc import ABC, abstractmethod

from stays_crawler.models import CrawlRequest, SeedHit


class SearchSource(ABC):
    name: str

    @abstractmethod
    def discover(self, request: CrawlRequest) -> list[SeedHit]:
        raise NotImplementedError
