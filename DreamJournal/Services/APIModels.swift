import Foundation

// 与 docs/API.md 一一对应的传输结构。日期统一用 ISO8601 字符串。

struct DayEntryDTO: Codable {
    var id: UUID
    var date: Date
    var title: String
    var content: String
    var mood: String
    var tags: [String]

    init(_ e: DayEntry) {
        id = e.id; date = e.date; title = e.title; content = e.content; mood = e.mood.rawValue; tags = e.tags
    }
}

struct DreamEntryDTO: Codable {
    var id: UUID
    var title: String
    var content: String
    var dreamDate: Date
    var recordedAt: Date
    var emotions: [String]
    var isLucid: Bool
    var tags: [String]

    init(_ e: DreamEntry) {
        id = e.id; title = e.title; content = e.content; dreamDate = e.dreamDate; recordedAt = e.recordedAt
        emotions = e.emotions; isLucid = e.isLucid; tags = e.tags
    }
}

struct SyncRequest: Codable {
    var userId: String
    var days: [DayEntryDTO]
    var dreams: [DreamEntryDTO]
}

struct AnalyzeRequest: Codable {
    struct Options: Codable {
        var lookbackDays = 7
        var maxRelated = 5
        var language = "en"
    }

    var userId: String
    var dream: DreamEntryDTO
    var options = Options()
}

struct AnalyzeResponse: Codable {
    var analysisId: String
    var summary: String
    var themes: [String]
    var symbols: [DreamAnalysis.Symbol]
    var relatedDays: [DreamAnalysis.RelatedEntry]
    var relatedDreams: [DreamAnalysis.RelatedEntry]
    var emotionalTone: String
    var suggestion: String
    var model: String?
    var generatedAt: Date

    var analysis: DreamAnalysis {
        DreamAnalysis(summary: summary, themes: themes, symbols: symbols, relatedDays: relatedDays,
                      relatedDreams: relatedDreams, emotionalTone: emotionalTone, suggestion: suggestion,
                      generatedAt: generatedAt, source: .gemini, model: model)
    }
}

struct KeywordDTO: Codable {
    var name: String
    var kind: String
    var aliases: [String]

    init(_ k: Keyword) {
        name = k.name; kind = k.kind.rawValue; aliases = k.aliases
    }
}

struct KeywordSuggestRequest: Codable {
    struct Options: Codable {
        var language = "en"
        var maxSuggestions = 6
    }

    var userId: String
    var dreams: [DreamEntryDTO]
    var existingKeywords: [KeywordDTO]
    var options = Options()
}

struct KeywordSuggestResponse: Codable {
    var suggestions: [KeywordSuggestion]
    var model: String?
    var generatedAt: Date
}

struct APIErrorResponse: Codable {
    struct Body: Codable {
        var code: String
        var message: String
    }
    var error: Body
}
