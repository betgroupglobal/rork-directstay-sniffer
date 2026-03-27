import SwiftUI

enum AppTheme {
    static let coral = Color(red: 0.95, green: 0.45, blue: 0.35)
    static let burntOrange = Color(red: 0.92, green: 0.55, blue: 0.28)
    static let amber = Color(red: 0.96, green: 0.72, blue: 0.26)
    static let peach = Color(red: 1.0, green: 0.78, blue: 0.62)
    static let dustyPurple = Color(red: 0.58, green: 0.38, blue: 0.62)
    static let deepNavy = Color(red: 0.08, green: 0.1, blue: 0.18)
    static let charcoal = Color(red: 0.14, green: 0.16, blue: 0.22)

    static let savingsGreen = Color(red: 0.2, green: 0.78, blue: 0.45)
    static let warningAmber = Color(red: 0.95, green: 0.75, blue: 0.2)
    static let otaRed = Color(red: 0.9, green: 0.3, blue: 0.3)

    static let sunsetGradient = LinearGradient(
        colors: [peach, coral, burntOrange, dustyPurple.opacity(0.6)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardGradient = LinearGradient(
        stops: [
            .init(color: .clear, location: 0.35),
            .init(color: .black.opacity(0.75), location: 1.0)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static func pinColor(for strength: BookingStrength) -> Color {
        switch strength {
        case .direct: savingsGreen
        case .alternative: warningAmber
        case .mainstreamOnly: otaRed
        }
    }
}
