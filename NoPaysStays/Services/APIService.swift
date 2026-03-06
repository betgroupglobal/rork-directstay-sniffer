import Foundation

nonisolated enum APIError: Error, LocalizedError, Sendable {
    case invalidURL
    case invalidResponse
    case serverError(Int)
    case decodingError(String)
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid URL"
        case .invalidResponse: "Invalid response from server"
        case .serverError(let code): "Server error (\(code))"
        case .decodingError(let msg): "Failed to parse response: \(msg)"
        case .networkError(let msg): "Network error: \(msg)"
        }
    }
}

actor APIService {
    static let shared = APIService()

    private let baseURL = "https://directstay-crawl-api.vercel.app"
    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        session = URLSession(configuration: config)
        decoder = JSONDecoder()
    }

    func crawl(_ request: CrawlRequest) async throws -> CrawlResponse {
        guard let url = URL(string: "\(baseURL)/api/v1/crawl") else {
            throw APIError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(httpResponse.statusCode)
        }

        do {
            return try decoder.decode(CrawlResponse.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }

    func crawlToProperties(_ request: CrawlRequest) async throws -> [Property] {
        let response = try await crawl(request)
        return response.results.map { hit in
            Property.fromBookingHit(hit)
        }
    }

    func testGuestyWebhook() async throws -> GuestyWebhookResponse {
        guard let url = URL(string: "\(baseURL)/api/v1/webhooks/guesty") else {
            throw APIError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("test.ping", forHTTPHeaderField: "X-Guesty-Event")

        let testPayload: [String: Any] = [
            "event": "test.ping",
            "title": "Webhook Test",
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: testPayload)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(httpResponse.statusCode)
        }

        do {
            return try decoder.decode(GuestyWebhookResponse.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }

    func checkHealth() async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/health") else {
            throw APIError.invalidURL
        }

        let (_, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }

        return (200...299).contains(httpResponse.statusCode)
    }

    func lookupDirectBooking(for property: Property) async throws -> [BookingHit] {
        var queries: [String] = []

        let name = property.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty && name != property.bookingLinks.first?.platform {
            queries.append("\(name) direct booking website")
        }

        if let contact = property.ownerContact, let ownerName = contact.name, !ownerName.isEmpty {
            let loc = [property.suburb, property.state].filter { !$0.isEmpty }.joined(separator: " ")
            queries.append("\(ownerName) holiday rental \(loc) book direct")
        }

        let addressParts = [property.address, property.suburb, property.state, property.postcode].filter { !$0.isEmpty }
        if addressParts.count >= 2 {
            queries.append("\(addressParts.joined(separator: " ")) holiday house owner website")
        }

        if !property.suburb.isEmpty {
            let bedStr = property.bedrooms > 0 ? "\(property.bedrooms) bedroom" : ""
            queries.append("\(property.suburb) \(bedStr) holiday rental direct booking -airbnb -booking.com".trimmingCharacters(in: .whitespaces))
        }

        if queries.isEmpty {
            queries.append("\(name) holiday rental direct")
        }

        var allHits: [BookingHit] = []
        var seenURLs: Set<String> = []

        for query in queries.prefix(3) {
            let request = CrawlRequest(
                location: query,
                max_results: 10
            )
            do {
                let response = try await crawl(request)
                for hit in response.results {
                    if !seenURLs.contains(hit.booking_url) {
                        seenURLs.insert(hit.booking_url)
                        allHits.append(hit)
                    }
                }
            } catch {
                continue
            }
        }

        return allHits.sorted { $0.score > $1.score }
    }

    var webhookURL: String {
        "\(baseURL)/api/v1/webhooks/guesty"
    }

    nonisolated var webhookURLSync: String {
        "https://directstay-crawl-api.vercel.app/api/v1/webhooks/guesty"
    }
}
