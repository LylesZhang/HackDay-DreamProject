import Foundation

/// 本地版关键词提炼：Mock 模式和后端不可用时使用。
/// 统计最近几天的梦里反复出现的已有关键词、标签和常见词，按出现次数排序。
enum KeywordExtractor {
    static let lookbackDays = 3

    private static let personWords = [
        "grandma", "grandpa", "nana", "mom", "dad", "mother", "father", "sister", "brother", "friend", "classmate",
        "teacher", "roommate", "coworker", "boss", "ex", "partner", "boyfriend", "girlfriend", "stranger", "child",
        "baby", "interviewer",
    ]
    private static let sceneWords = [
        "high school", "middle school", "college", "childhood", "school", "classroom", "exam", "office", "old house",
        "yard", "hometown", "hospital", "subway station", "station", "airport", "dorm", "moving", "interview",
        "graduation", "strange city", "city", "beach", "forest", "alley",
    ]
    private static let imageryWords = [
        "whale", "water", "sea", "ocean", "flying", "falling", "tower", "stairs", "hallway", "door", "key", "mirror",
        "storm", "rain", "fire", "snake", "cat", "dog", "bird", "moon", "stars", "persimmon tree", "tree", "bridge",
        "cracks", "teeth", "lost", "elevator", "phone", "sunset",
    ]

    static func kind(for word: String) -> Keyword.Kind {
        if personWords.contains(word.lowercased()) { return .person }
        if sceneWords.contains(word.lowercased()) { return .scene }
        return .imagery
    }

    /// 最近 `lookbackDays` 天（含今天）的梦
    static func recentDreams(_ dreams: [DreamEntry], now: Date = .now, calendar cal: Calendar = .current) -> [DreamEntry] {
        let today = cal.startOfDay(for: now)
        return dreams
            .filter { (0...lookbackDays).contains(cal.dateComponents([.day], from: cal.startOfDay(for: $0.dreamDate), to: today).day ?? 99) }
            .sorted { $0.dreamDate > $1.dreamDate }
    }

    static func suggest(recentDreams: [DreamEntry], existing: [Keyword], limit: Int = 6) -> [KeywordSuggestion] {
        struct Hit { var kind: Keyword.Kind; var titles: [String]; var isExisting: Bool }
        var hits: [String: Hit] = [:]

        for dream in recentDreams {
            let text = dream.title + dream.content + dream.tags.joined(separator: " ")
            var found: [String: (Keyword.Kind, Bool)] = [:]
            for k in existing where k.isMentioned(in: text) { found[k.name] = (k.kind, true) }
            for tag in dream.tags where found[tag] == nil
                && !existing.contains(where: { k in k.terms.contains { $0.caseInsensitiveCompare(tag) == .orderedSame } }) {
                found[tag] = (kind(for: tag), false)
            }
            for word in personWords + sceneWords + imageryWords
            where !Keyword.ranges(of: word, in: text).isEmpty && found[word] == nil
                && !found.keys.contains(where: { $0.caseInsensitiveCompare(word) == .orderedSame })
                && !existing.contains(where: { k in k.terms.contains { $0.caseInsensitiveCompare(word) == .orderedSame } }) {
                found[word] = (kind(for: word), false)
            }
            for (word, (kind, isExisting)) in found {
                hits[word, default: Hit(kind: kind, titles: [], isExisting: isExisting)].titles.append(dream.title)
            }
        }

        // 被更长、出现次数不少于它的词包含时去掉（保留 “strange city” 而不是 “city”）
        let words = Array(hits.keys)
        let kept = words.filter { w in
            !words.contains { other in other != w && other.contains(w) && hits[other]!.titles.count >= hits[w]!.titles.count }
        }

        return kept
            .sorted {
                let a = hits[$0]!, b = hits[$1]!
                if a.titles.count != b.titles.count { return a.titles.count > b.titles.count }
                if a.isExisting != b.isExisting { return a.isExisting }
                return $0.count > $1.count
            }
            .prefix(limit)
            .map { word in
                let hit = hits[word]!
                let reason = hit.titles.count > 1
                    ? "In \(hit.titles.count) dreams from the last \(lookbackDays) days"
                    : "From “\(hit.titles[0])”"
                // 词表里是小写，展示时首字母大写
                let name = word.first.map { $0.uppercased() + word.dropFirst() } ?? word
                return KeywordSuggestion(name: name, kind: hit.kind, reason: reason)
            }
    }
}
