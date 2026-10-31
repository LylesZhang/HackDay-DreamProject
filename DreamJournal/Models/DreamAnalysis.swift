import Foundation

/// AI 联合分析报告（Mock 与后端 Gemini 返回同一结构）。
struct DreamAnalysis: Codable, Hashable {
    struct Symbol: Codable, Hashable, Identifiable {
        var symbol: String
        var interpretation: String
        var id: String { symbol }
    }

    struct RelatedEntry: Codable, Hashable, Identifiable {
        var entryId: UUID
        var date: Date
        var snippet: String
        var reason: String
        var id: UUID { entryId }
    }

    enum Source: String, Codable {
        case mock, gemini
    }

    var summary: String
    var themes: [String]
    var symbols: [Symbol]
    var relatedDays: [RelatedEntry]
    var relatedDreams: [RelatedEntry]
    var emotionalTone: String
    var suggestion: String
    var generatedAt: Date
    var source: Source
    var model: String?
}
