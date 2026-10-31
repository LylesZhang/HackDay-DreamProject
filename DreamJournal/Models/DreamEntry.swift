import Foundation

/// 梦境日记。`dreamDate` 指做梦的那一晚（与当天的白天日记配对）。
struct DreamEntry: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var dreamDate: Date
    var recordedAt: Date
    var title: String
    var content: String
    var emotions: [String] = []
    var isLucid: Bool = false
    var tags: [String] = []
    var analysis: DreamAnalysis?

    static let emotionOptions = ["Uneasy", "Joyful", "Confused", "Afraid", "Nostalgic", "Excited", "Sad", "Peaceful", "Free"]
}
