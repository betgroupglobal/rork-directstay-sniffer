import Foundation

struct AnalysisTarget: Identifiable {
    let id: String = UUID().uuidString
    let url: String
    let platformName: String
}
