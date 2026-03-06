import Foundation

enum AIAnalysisService {
    private static let mercuryBaseURL = "https://api.inceptionlabs.ai/v1/chat/completions"
    private static let model = "mercury-2"

    static func analyzeProperty(
        url: String,
        platformName: String,
        location: String,
        criteria: SearchCriteria?
    ) async throws -> PropertyAnalysis {
        let prompt = buildAnalysisPrompt(
            url: url,
            platformName: platformName,
            location: location,
            criteria: criteria
        )

        let responseText = try await sendMercuryRequest(prompt: prompt)
        let parsed = parseAnalysisResponse(responseText)

        return PropertyAnalysis(
            url: url,
            platformName: platformName,
            location: location,
            propertyOfferings: parsed.propertyOfferings,
            businessPresence: parsed.businessPresence,
            reviewsSummary: parsed.reviewsSummary,
            paymentMethods: parsed.paymentMethods,
            directBookingScore: parsed.directBookingScore,
            keyInsights: parsed.keyInsights
        )
    }

    private static func sendMercuryRequest(prompt: String) async throws -> String {
        let apiKey = Config.MERCURY_API_KEY
        guard !apiKey.isEmpty else {
            throw AIAnalysisError.missingConfiguration
        }

        guard let endpoint = URL(string: mercuryBaseURL) else {
            throw AIAnalysisError.invalidURL
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 120

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": "You are a holiday rental analyst helping travellers find direct bookings to avoid OTA fees. Be specific, practical, and actionable."],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 2000,
            "temperature": 0.7
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIAnalysisError.networkError
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw AIAnalysisError.serverError(httpResponse.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            let rawString = String(data: data, encoding: .utf8) ?? ""
            if !rawString.isEmpty { return rawString }
            throw AIAnalysisError.decodingError
        }

        return content
    }

    private static func buildAnalysisPrompt(
        url: String,
        platformName: String,
        location: String,
        criteria: SearchCriteria?
    ) -> String {
        var context = "Platform: \(platformName)\nURL: \(url)\nLocation: \(location)"
        if let c = criteria {
            context += "\nGuests: \(c.guests), Bedrooms: \(c.bedrooms), Bathrooms: \(c.bathrooms)"
            if c.isPetFriendly { context += "\nPet-friendly required" }
            if let price = c.maxPricePerNight { context += "\nMax budget: $\(price)/night" }
        }

        return """
        Analyze this listing/platform link and provide insights in EXACTLY this format. Use the section headers exactly as shown:

        **PROPERTY OFFERINGS**
        Based on the platform (\(platformName)) and URL, describe what type of property/accommodation this likely is. What amenities, features, and experiences can the guest expect? Consider the location (\(location)) and the platform's speciality. Be specific and practical.

        **BUSINESS PRESENCE**
        Analyze whether this is likely an individual owner, property manager, or company. Does the platform/URL suggest they have their own domain or booking website? Look at the URL structure for clues. Suggest how to find their direct website (Google the property name + location, check their social media, look for "book direct" on their page). Mention if the platform itself encourages direct relationships between hosts and guests.

        **REVIEWS & REPUTATION**
        Where can the traveller find independent reviews for this property or host? Suggest specific places to look: Google Reviews, TripAdvisor, ProductReview.com.au, Facebook page reviews, Whirlpool forums, Reddit threads. Explain how to cross-reference the property name/address across review platforms to build confidence.

        **PAYMENT METHODS**
        Based on the platform (\(platformName)), what payment methods are typically accepted? Differentiate between platform-mediated payments vs. direct payments to the owner. Mention if direct bank transfer, PayPal, Stripe, credit card, or cash on arrival are common. Flag any payment safety considerations for direct bookings. Advise on what payment protection exists (or doesn't) when booking direct vs. through the platform.

        **DIRECT BOOKING SCORE**
        Rate 1-10 how likely this source is to lead to a direct booking (bypassing OTA fees). 10 = guaranteed direct, 1 = still on a major OTA. Just the number.

        **KEY INSIGHTS**
        List 3-5 bullet points with actionable tips specific to this platform/listing. Each bullet should start with "- ".

        Context:
        \(context)
        """
    }

    private static func parseAnalysisResponse(_ text: String) -> AIAnalysisResponse {
        let offerings = extractSection(from: text, header: "PROPERTY OFFERINGS", nextHeaders: ["BUSINESS PRESENCE", "REVIEWS", "PAYMENT", "DIRECT BOOKING SCORE", "KEY INSIGHTS"])
        let business = extractSection(from: text, header: "BUSINESS PRESENCE", nextHeaders: ["REVIEWS", "PAYMENT", "DIRECT BOOKING SCORE", "KEY INSIGHTS"])
        let reviews = extractSection(from: text, header: "REVIEWS", nextHeaders: ["PAYMENT", "DIRECT BOOKING SCORE", "KEY INSIGHTS"])
        let payment = extractSection(from: text, header: "PAYMENT", nextHeaders: ["DIRECT BOOKING SCORE", "KEY INSIGHTS"])
        let scoreText = extractSection(from: text, header: "DIRECT BOOKING SCORE", nextHeaders: ["KEY INSIGHTS"])
        let insightsText = extractSection(from: text, header: "KEY INSIGHTS", nextHeaders: [])

        let score = Int(scoreText.filter(\.isNumber).prefix(2)) ?? 5

        let insights = insightsText
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.hasPrefix("- ") || $0.hasPrefix("* ") }
            .map { String($0.dropFirst(2)) }

        return AIAnalysisResponse(
            propertyOfferings: offerings.trimmingCharacters(in: .whitespacesAndNewlines),
            businessPresence: business.trimmingCharacters(in: .whitespacesAndNewlines),
            reviewsSummary: reviews.trimmingCharacters(in: .whitespacesAndNewlines),
            paymentMethods: payment.trimmingCharacters(in: .whitespacesAndNewlines),
            directBookingScore: min(10, max(1, score)),
            keyInsights: insights.isEmpty ? ["Review the listing carefully for direct booking options"] : insights
        )
    }

    private static func extractSection(from text: String, header: String, nextHeaders: [String]) -> String {
        let patterns = [
            "**\(header)**",
            "## \(header)",
            "### \(header)",
            "\(header):",
            "\(header)"
        ]

        var startIndex: String.Index?
        for pattern in patterns {
            if let range = text.range(of: pattern, options: .caseInsensitive) {
                startIndex = range.upperBound
                break
            }
        }

        guard let start = startIndex else { return "" }

        var endIndex = text.endIndex
        for nextHeader in nextHeaders {
            let nextPatterns = [
                "**\(nextHeader)**",
                "**\(nextHeader)",
                "## \(nextHeader)",
                "### \(nextHeader)"
            ]
            for pattern in nextPatterns {
                if let range = text.range(of: pattern, options: .caseInsensitive, range: start..<text.endIndex) {
                    if range.lowerBound < endIndex {
                        endIndex = range.lowerBound
                    }
                }
            }
        }

        return String(text[start..<endIndex])
    }
}

nonisolated enum AIAnalysisError: Error, LocalizedError, Sendable {
    case missingConfiguration
    case invalidURL
    case networkError
    case serverError(Int)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            "Mercury API key not configured. Please check your settings."
        case .invalidURL:
            "Invalid API endpoint."
        case .networkError:
            "Network error. Please check your connection."
        case .serverError(let code):
            "Mercury API error (\(code)). Please try again."
        case .decodingError:
            "Failed to process AI response."
        }
    }
}
