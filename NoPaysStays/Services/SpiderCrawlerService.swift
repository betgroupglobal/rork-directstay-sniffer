import Foundation

@Observable
final class SpiderCrawlerService {
    var results: [CrawlResult] = []
    var status: SpiderStatus = .idle
    var crawledCount: Int = 0
    var totalSources: Int = 0
    var currentSource: String = ""
    var logs: [SpiderLog] = []

    private var crawlTask: Task<Void, Never>?
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 45
        config.timeoutIntervalForResource = 90
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "en-AU,en;q=0.9",
            "Accept-Encoding": "gzip, deflate",
            "Connection": "keep-alive"
        ]
        config.waitsForConnectivity = true
        session = URLSession(configuration: config)
    }

    func startCrawl(criteria: SearchCriteria) {
        stopCrawl()
        results = []
        logs = []
        crawledCount = 0

        let platformSearches = DeepSearchService.generateSearchLinks(for: criteria)
        totalSources = platformSearches.count
        status = .crawling(source: "Initializing…", progress: 0)

        addLog("Spider started — \(totalSources) sources to crawl", level: .info)
        addLog("Target: \(criteria.location) · \(criteria.guests) guests · \(criteria.bedrooms) bed", level: .info)

        crawlTask = Task { [weak self] in
            guard let self else { return }

            let batches = platformSearches.chunked(into: 2)

            for (batchIndex, batch) in batches.enumerated() {
                if Task.isCancelled { break }

                await withTaskGroup(of: [CrawlResult].self) { group in
                    for search in batch {
                        group.addTask { [weak self] in
                            guard let self else { return [] }
                            await self.updateCurrentSource(search.platformName)
                            return await self.crawlSource(search, criteria: criteria)
                        }
                    }

                    for await batchResults in group {
                        if Task.isCancelled { break }
                        for result in batchResults {
                            self.appendResult(result)
                        }
                    }
                }

                crawledCount += batch.count
                let progress = Double(crawledCount) / Double(totalSources)
                status = .crawling(source: currentSource, progress: progress)

                if batchIndex < batches.count - 1 {
                    try? await Task.sleep(for: .seconds(1))
                }
            }

            if !Task.isCancelled {
                let deduped = deduplicateResults(results)
                results = deduped.sorted { $0.directBookingLikelihood < $1.directBookingLikelihood }
                addLog("Hunt complete — \(results.count) unique results found", level: .success)
                status = .completed
            }
        }
    }

    func stopCrawl() {
        crawlTask?.cancel()
        crawlTask = nil
        if status.isActive {
            status = .idle
            addLog("Spider stopped by user", level: .warning)
        }
    }

    private func updateCurrentSource(_ name: String) {
        currentSource = name
    }

    private func appendResult(_ result: CrawlResult) {
        results.append(result)
    }

    private func crawlSource(_ search: PlatformSearch, criteria: SearchCriteria) async -> [CrawlResult] {
        addLog("Crawling \(search.platformName)…", level: .info)

        let maxRetries = 2
        for attempt in 0...maxRetries {
            if Task.isCancelled { return [] }

            do {
                var request = URLRequest(url: search.searchURL)
                request.timeoutInterval = 45
                request.cachePolicy = .reloadIgnoringLocalCacheData

                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    addLog("\(search.platformName): No response", level: .warning)
                    return []
                }

                if httpResponse.statusCode == 429 || (500...599).contains(httpResponse.statusCode) {
                    if attempt < maxRetries {
                        let delay = Double(attempt + 1) * 2.0
                        addLog("\(search.platformName): HTTP \(httpResponse.statusCode), retrying in \(Int(delay))s…", level: .warning)
                        try? await Task.sleep(for: .seconds(delay))
                        continue
                    }
                    addLog("\(search.platformName): HTTP \(httpResponse.statusCode) after retries", level: .warning)
                    return []
                }

                guard (200...399).contains(httpResponse.statusCode) else {
                    addLog("\(search.platformName): HTTP \(httpResponse.statusCode)", level: .warning)
                    return []
                }

                guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
                    addLog("\(search.platformName): Could not decode response", level: .warning)
                    return []
                }

                let extracted = extractListings(from: html, source: search, criteria: criteria)
                addLog("\(search.platformName): Found \(extracted.count) results", level: extracted.isEmpty ? .warning : .success)
                return extracted

            } catch is CancellationError {
                return []
            } catch let error as URLError where error.code == .timedOut || error.code == .networkConnectionLost {
                if attempt < maxRetries {
                    let delay = Double(attempt + 1) * 2.0
                    addLog("\(search.platformName): Timeout, retrying in \(Int(delay))s…", level: .warning)
                    try? await Task.sleep(for: .seconds(delay))
                    continue
                }
                addLog("\(search.platformName): Timed out after \(maxRetries + 1) attempts", level: .error)
                return []
            } catch {
                addLog("\(search.platformName): \(error.localizedDescription)", level: .error)
                return []
            }
        }
        return []
    }

    private func extractListings(from html: String, source: PlatformSearch, criteria: SearchCriteria) -> [CrawlResult] {
        var found: [CrawlResult] = []

        let links = extractLinks(from: html, baseURL: source.searchURL)
        let titles = extractTitles(from: html)
        let snippets = extractSnippets(from: html, location: criteria.location)
        let prices = extractPrices(from: html)

        if !links.isEmpty {
            let maxResults = min(links.count, 15)
            for i in 0..<maxResults {
                let link = links[i]

                if isOTADomain(link) { continue }
                if link.contains("google.com") || link.contains("bing.com") || link.contains("duckduckgo.com") { continue }
                if link.count < 15 { continue }

                let title = i < titles.count ? titles[i] : extractDomainName(from: link)
                let snippet = i < snippets.count ? snippets[i] : ""
                let price = i < prices.count ? prices[i] : nil
                let likelihood = assessDirectBookingLikelihood(url: link, html: html, category: source.category)

                found.append(CrawlResult(
                    title: cleanText(title),
                    url: link,
                    snippet: cleanText(snippet),
                    sourcePlatform: source.platformName,
                    category: source.category,
                    feeIndicator: source.feePercentage ?? "Varies",
                    directBookingLikelihood: likelihood,
                    ownerContact: extractContact(from: html, nearURL: link),
                    priceHint: price
                ))
            }
        }

        if found.isEmpty && source.category != .searchEngine {
            let pageTitle = extractPageTitle(from: html)
            if !pageTitle.isEmpty {
                found.append(CrawlResult(
                    title: pageTitle,
                    url: source.searchURL.absoluteString,
                    snippet: "Platform page loaded — browse for listings matching your criteria",
                    sourcePlatform: source.platformName,
                    category: source.category,
                    feeIndicator: source.feePercentage ?? "Varies",
                    directBookingLikelihood: source.category == .directBooking ? .high : .medium
                ))
            }
        }

        return found
    }

    private func extractLinks(from html: String, baseURL: URL) -> [String] {
        var links: [String] = []
        let pattern = #"href\s*=\s*["']([^"']+)["']"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return links }

        let nsHTML = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: min(nsHTML.length, 500_000)))

        for match in matches {
            guard match.numberOfRanges > 1 else { continue }
            var href = nsHTML.substring(with: match.range(at: 1))

            if href.hasPrefix("//") {
                href = "https:" + href
            } else if href.hasPrefix("/") {
                if let base = URL(string: href, relativeTo: baseURL)?.absoluteString {
                    href = base
                }
            }

            guard href.hasPrefix("http"), href.count > 15 else { continue }

            if href.contains("listing") || href.contains("property") || href.contains("accommodation")
                || href.contains("holiday") || href.contains("rental") || href.contains("stay")
                || href.contains("house") || href.contains("cabin") || href.contains("cottage")
                || href.contains("villa") || href.contains("apartment") || href.contains("book")
                || href.contains("detail") || href.contains("view") {
                links.append(href)
            }
        }

        return Array(Set(links))
    }

    private func extractTitles(from html: String) -> [String] {
        var titles: [String] = []

        let patterns = [
            #"<h[1-3][^>]*>([^<]+)</h[1-3]>"#,
            #"class="[^"]*title[^"]*"[^>]*>([^<]+)<"#,
            #"class="[^"]*name[^"]*"[^>]*>([^<]+)<"#,
            #"data-testid="[^"]*title[^"]*"[^>]*>([^<]+)<"#,
            #"aria-label="([^"]+)"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            let nsHTML = html as NSString
            let matches = regex.matches(in: html, range: NSRange(location: 0, length: min(nsHTML.length, 500_000)))

            for match in matches where match.numberOfRanges > 1 {
                let text = nsHTML.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                if text.count > 5 && text.count < 200 {
                    titles.append(text)
                }
            }
        }

        return titles
    }

    private func extractSnippets(from html: String, location: String) -> [String] {
        var snippets: [String] = []
        let patterns = [
            #"<p[^>]*>([^<]{20,300})</p>"#,
            #"class="[^"]*description[^"]*"[^>]*>([^<]{20,300})<"#,
            #"class="[^"]*snippet[^"]*"[^>]*>([^<]{20,300})<"#,
            #"class="[^"]*summary[^"]*"[^>]*>([^<]{20,300})<"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            let nsHTML = html as NSString
            let matches = regex.matches(in: html, range: NSRange(location: 0, length: min(nsHTML.length, 500_000)))

            for match in matches where match.numberOfRanges > 1 {
                let text = nsHTML.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                if text.count > 20 {
                    snippets.append(text)
                }
            }
        }

        return snippets
    }

    private func extractPrices(from html: String) -> [String] {
        var prices: [String] = []
        let pattern = #"\$\s*(\d{2,4})(?:\s*(?:per|/)\s*(?:night|pn|p/n))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return prices }

        let nsHTML = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: min(nsHTML.length, 500_000)))

        for match in matches {
            let fullMatch = nsHTML.substring(with: match.range)
            prices.append(fullMatch)
        }

        return prices
    }

    private func extractContact(from html: String, nearURL: String) -> String? {
        let emailPattern = #"[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}"#
        let phonePattern = #"(?:\+61|0)[2-478][\s\-]?\d{4}[\s\-]?\d{4}"#

        if let regex = try? NSRegularExpression(pattern: emailPattern),
           let match = regex.firstMatch(in: html, range: NSRange(location: 0, length: min((html as NSString).length, 500_000))) {
            let email = (html as NSString).substring(with: match.range)
            if !email.contains("example") && !email.contains("noreply") && !email.contains("support@") {
                return email
            }
        }

        if let regex = try? NSRegularExpression(pattern: phonePattern),
           let match = regex.firstMatch(in: html, range: NSRange(location: 0, length: min((html as NSString).length, 500_000))) {
            return (html as NSString).substring(with: match.range)
        }

        return nil
    }

    private func extractPageTitle(from html: String) -> String {
        let pattern = #"<title[^>]*>([^<]+)</title>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: html, range: NSRange(location: 0, length: min((html as NSString).length, 10_000))) else {
            return ""
        }
        return (html as NSString).substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractDomainName(from url: String) -> String {
        guard let host = URL(string: url)?.host else { return url }
        return host.replacingOccurrences(of: "www.", with: "").capitalized
    }

    private func isOTADomain(_ url: String) -> Bool {
        let otaDomains = [
            "airbnb.com", "airbnb.com.au",
            "booking.com",
            "expedia.com", "expedia.com.au",
            "hotels.com",
            "trivago.com",
            "agoda.com",
            "trip.com",
            "kayak.com"
        ]
        return otaDomains.contains { url.contains($0) }
    }

    private func assessDirectBookingLikelihood(url: String, html: String, category: PlatformCategory) -> DirectBookingLikelihood {
        if category == .directBooking { return .high }

        let directSignals = [
            "book direct", "book now", "enquire", "contact us",
            "contact owner", "owner direct", "no booking fee",
            "phone:", "email:", "call us"
        ]
        let htmlLower = html.lowercased()
        let signalCount = directSignals.filter { htmlLower.contains($0) }.count

        if signalCount >= 3 { return .high }

        if category == .alternativePlatform && signalCount >= 1 { return .medium }

        if category == .classifieds { return .high }

        if isSmallDomain(url) { return .high }

        return signalCount > 0 ? .medium : .low
    }

    private func isSmallDomain(_ url: String) -> Bool {
        guard let host = URL(string: url)?.host?.lowercased() else { return false }
        let majorDomains = [
            "google.com", "bing.com", "facebook.com", "reddit.com",
            "gumtree.com.au", "domain.com.au", "realestate.com.au",
            "stayz.com.au", "vrbo.com", "tripadvisor.com",
            "whirlpool.net.au", "duckduckgo.com"
        ]
        return !majorDomains.contains { host.contains($0) }
    }

    private func cleanText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&#x27;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func deduplicateResults(_ results: [CrawlResult]) -> [CrawlResult] {
        var seen = Set<String>()
        var unique: [CrawlResult] = []
        for result in results {
            let normalized = result.url.lowercased()
                .replacingOccurrences(of: "www.", with: "")
                .replacingOccurrences(of: "https://", with: "")
                .replacingOccurrences(of: "http://", with: "")

            let key = String(normalized.prefix(100))
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(result)
            }
        }
        return unique
    }

    private func addLog(_ message: String, level: SpiderLog.Level) {
        logs.append(SpiderLog(message: message, level: level))
    }
}

nonisolated struct SpiderLog: Identifiable, Sendable {
    let id: String = UUID().uuidString
    let message: String
    let level: Level
    let timestamp: Date = Date()

    nonisolated enum Level: Sendable {
        case info, success, warning, error
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
