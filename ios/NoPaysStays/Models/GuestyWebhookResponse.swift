import Foundation

nonisolated struct GuestyWebhookResponse: Codable, Sendable {
    let status: String
    let saved: Int
}
