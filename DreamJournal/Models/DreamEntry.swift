import Foundation

/// 梦境日记。`dreamDate` 指做梦的那一晚（与当天的白天日记配对）。
struct DreamEntry: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var dreamDate: Date
    var recordedAt: Date
    var title: String
    var content: String
    var emotions: [String] = []
    /// 清晰度 1–5
    var vividness: Int = 3
    var isLucid: Bool = false
    var tags: [String] = []
    var analysis: DreamAnalysis?

    static let emotionOptions = ["不安", "愉快", "困惑", "恐惧", "怀念", "兴奋", "悲伤", "平静", "自由"]
}
