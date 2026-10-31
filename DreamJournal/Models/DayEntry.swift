import Foundation

enum Mood: String, Codable, CaseIterable, Identifiable {
    case happy, calm, neutral, stressed, sad

    var id: String { rawValue }

    /// 用天气隐喻心情（SF Symbols，任何设备都能正常显示）
    var symbol: String {
        switch self {
        case .happy: "sun.max.fill"
        case .calm: "leaf.fill"
        case .neutral: "cloud.fill"
        case .stressed: "bolt.fill"
        case .sad: "cloud.rain.fill"
        }
    }

    /// 图标颜色（十六进制）
    var colorHex: UInt32 {
        switch self {
        case .happy: 0xFFB020
        case .calm: 0x6CC08B
        case .neutral: 0x9AA5B1
        case .stressed: 0xF2994A
        case .sad: 0x5B8DEF
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
