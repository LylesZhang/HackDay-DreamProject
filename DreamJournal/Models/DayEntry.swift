import Foundation

enum Mood: String, Codable, CaseIterable, Identifiable {
    case happy, calm, neutral, stressed, sad

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .happy: "😊"
        case .calm: "😌"
        case .neutral: "😐"
        case .stressed: "😣"
        case .sad: "😢"
        }
    }

    var label: String {
        switch self {
        case .happy: "开心"
        case .calm: "平静"
        case .neutral: "一般"
        case .stressed: "焦虑"
        case .sad: "低落"
        }
    }
}

/// 白天日记：简化版，记录今天发生了什么。
struct DayEntry: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var date: Date
    var title: String
    var content: String
    var mood: Mood
    var tags: [String] = []
}
