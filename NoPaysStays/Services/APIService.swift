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
}
