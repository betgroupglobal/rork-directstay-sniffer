import Foundation

@Observable
final class WebSearchAPIService {
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        session = URLSession(configuration: config)
    }

    func search(query: String, provider: SearchAPIProvider) async throws -> [WebSearchResult] {
        switch provider {
        case .google:
            return try await googleSearch(query: query)
        case .bing:
            return try await bingSearch(query: query)
        case .serpAPI:
            return try await serpAPISearch(query: query)
        case .brave:
            return try await braveSearch(query: query)
        }
    }

    func searchAllProviders(query: String) async -> [WebSearchResult] {
        let providers = SearchAPIProvider.configuredProviders
        guard !providers.isEmpty else { return [] }

        for provider in providers {
            do {
                let results = try await search(query: query, provider: provider)
                if !results.isEmpty { return results }
            } catch {
                continue
            }
        }
        return []
    }

    private func googleSearch(query: String) async throws -> [WebSearchResult] {
        let apiKey = Config.GOOGLE_API_KEY
        let cx = Config.GOOGLE_CX
        guard !apiKey.isEmpty, !cx.isEmpty else { throw SearchAPIError.notConfigured(.google) }

        var components = URLComponents(string: "https://www.googleapis.com/customsearch/v1")!
        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "cx", value: cx),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "num", value: "10"),
            URLQueryItem(name: "gl", value: "au"),
            URLQueryItem(name: "cr", value: "countryAU")
        ]

        guard let url = components.url else { throw SearchAPIError.invalidURL }

        let (data, response) = try await session.data(from: url)
        try validateHTTPResponse(response, provider: .google)

        let decoded = try JSONDecoder().decode(GoogleSearchResponse.self, from: data)
        return decoded.items?.map { item in
            WebSearchResult(
                title: item.title,
                url: item.link,
                snippet: item.snippet ?? "",
                displayURL: item.displayLink ?? item.link,
                source: .google
            )
        } ?? []
    }

    private func bingSearch(query: String) async throws -> [WebSearchResult] {
        let apiKey = Config.BING_API_KEY
        guard !apiKey.isEmpty else { throw SearchAPIError.notConfigured(.bing) }

        var components = URLComponents(string: "https://api.bing.microsoft.com/v7.0/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "count", value: "15"),
            URLQueryItem(name: "mkt", value: "en-AU"),
            URLQueryItem(name: "responseFilter", value: "Webpages")
        ]

        guard let url = components.url else { throw SearchAPIError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")

        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response, provider: .bing)

        let decoded = try JSONDecoder().decode(BingSearchResponse.self, from: data)
        return decoded.webPages?.value?.map { page in
            WebSearchResult(
                title: page.name,
                url: page.url,
                snippet: page.snippet ?? "",
                displayURL: page.displayUrl ?? page.url,
                source: .bing
            )
        } ?? []
    }

    private func serpAPISearch(query: String) async throws -> [WebSearchResult] {
        let apiKey = Config.SERP_API_KEY
        guard !apiKey.isEmpty else { throw SearchAPIError.notConfigured(.serpAPI) }

        var components = URLComponents(string: "https://serpapi.com/search.json")!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "engine", value: "google"),
            URLQueryItem(name: "gl", value: "au"),
            URLQueryItem(name: "hl", value: "en"),
            URLQueryItem(name: "num", value: "15")
        ]

        guard let url = components.url else { throw SearchAPIError.invalidURL }

        let (data, response) = try await session.data(from: url)
        try validateHTTPResponse(response, provider: .serpAPI)

        let decoded = try JSONDecoder().decode(SerpAPIResponse.self, from: data)
        return decoded.organic_results?.map { result in
            WebSearchResult(
                title: result.title,
                url: result.link,
                snippet: result.snippet ?? "",
                displayURL: result.displayed_link ?? result.link,
                source: .serpAPI
            )
        } ?? []
    }

    private func braveSearch(query: String) async throws -> [WebSearchResult] {
        let apiKey = Config.BRAVE_API_KEY
        guard !apiKey.isEmpty else { throw SearchAPIError.notConfigured(.brave) }

        var components = URLComponents(string: "https://api.search.brave.com/res/v1/web/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "count", value: "15"),
            URLQueryItem(name: "country", value: "AU"),
            URLQueryItem(name: "search_lang", value: "en")
        ]

        guard let url = components.url else { throw SearchAPIError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-Subscription-Token")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response, provider: .brave)

        let decoded = try JSONDecoder().decode(BraveSearchResponse.self, from: data)
        return decoded.web?.results?.map { result in
            WebSearchResult(
                title: result.title,
                url: result.url,
                snippet: result.description ?? "",
                displayURL: result.url,
                source: .brave
            )
        } ?? []
    }

    private func validateHTTPResponse(_ response: URLResponse, provider: SearchAPIProvider) throws {
        guard let http = response as? HTTPURLResponse else {
            throw SearchAPIError.noResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw SearchAPIError.httpError(http.statusCode, provider)
        }
    }
}

nonisolated struct WebSearchResult: Sendable {
    let title: String
    let url: String
    let snippet: String
    let displayURL: String
    let source: SearchAPIProvider
}

nonisolated enum SearchAPIProvider: String, CaseIterable, Sendable {
    case google = "Google"
    case bing = "Bing"
    case serpAPI = "SerpAPI"
    case brave = "Brave"

    static var configuredProviders: [SearchAPIProvider] {
        var providers: [SearchAPIProvider] = []
        if !Config.SERP_API_KEY.isEmpty { providers.append(.serpAPI) }
        if !Config.GOOGLE_API_KEY.isEmpty && !Config.GOOGLE_CX.isEmpty { providers.append(.google) }
        if !Config.BING_API_KEY.isEmpty { providers.append(.bing) }
        if !Config.BRAVE_API_KEY.isEmpty { providers.append(.brave) }
        return providers
    }
}

nonisolated enum SearchAPIError: Error, LocalizedError, Sendable {
    case notConfigured(SearchAPIProvider)
    case invalidURL
    case noResponse
    case httpError(Int, SearchAPIProvider)
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured(let p): "\(p.rawValue) API not configured"
        case .invalidURL: "Invalid search URL"
        case .noResponse: "No response from search API"
        case .httpError(let code, let p): "\(p.rawValue) API error: HTTP \(code)"
        case .decodingError(let msg): "Failed to decode: \(msg)"
        }
    }
}

nonisolated struct GoogleSearchResponse: Codable, Sendable {
    let items: [GoogleSearchItem]?
}

nonisolated struct GoogleSearchItem: Codable, Sendable {
    let title: String
    let link: String
    let snippet: String?
    let displayLink: String?
}

nonisolated struct BingSearchResponse: Codable, Sendable {
    let webPages: BingWebPages?
}

nonisolated struct BingWebPages: Codable, Sendable {
    let value: [BingWebPage]?
}

nonisolated struct BingWebPage: Codable, Sendable {
    let name: String
    let url: String
    let snippet: String?
    let displayUrl: String?
}

nonisolated struct SerpAPIResponse: Codable, Sendable {
    let organic_results: [SerpAPIResult]?
}

nonisolated struct SerpAPIResult: Codable, Sendable {
    let title: String
    let link: String
    let snippet: String?
    let displayed_link: String?
}

nonisolated struct BraveSearchResponse: Codable, Sendable {
    let web: BraveWebResults?
}

nonisolated struct BraveWebResults: Codable, Sendable {
    let results: [BraveWebResult]?
}

nonisolated struct BraveWebResult: Codable, Sendable {
    let title: String
    let url: String
    let description: String?
}
