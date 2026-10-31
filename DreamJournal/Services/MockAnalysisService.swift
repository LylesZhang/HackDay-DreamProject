import Foundation

/// 本地模拟后端：时间窗口 + 关键词重叠检索相关日记，再用模板和意象词典生成报告。
/// 返回的结构与真实后端完全一致，方便离线演示。
struct MockAnalysisService: AnalysisService {
    var latency: Duration = .milliseconds(1600)

    func sync(days: [DayEntry], dreams: [DreamEntry]) async throws {}

    func suggestKeywords(recentDreams: [DreamEntry], existing: [Keyword]) async throws -> [KeywordSuggestion] {
        try await Task.sleep(for: .milliseconds(600))
        return KeywordExtractor.suggest(recentDreams: recentDreams, existing: existing)
    }

    func analyze(dream: DreamEntry, store: JournalStore) async throws -> DreamAnalysis {
        let days = store.dayEntries
        let dreams = store.dreamEntries
        try await Task.sleep(for: latency)
        return Self.buildReport(for: dream, days: days, dreams: dreams)
    }

    // MARK: - Retrieval

    private struct Scored<T> {
        var item: T
        var score: Int
        var shared: [String]
        var daysBefore: Int
    }

    static func buildReport(for dream: DreamEntry, days: [DayEntry], dreams: [DreamEntry]) -> DreamAnalysis {
        let cal = Calendar.current
        let dreamDay = cal.startOfDay(for: dream.dreamDate)
        let dreamKeys = Keywords(text: dream.title + ". " + dream.content, tags: dream.tags)

        // 1) 相关白天：梦之前 7 天内，时间越近、共同线索越多分越高
        let scoredDays: [Scored<DayEntry>] = days.compactMap { day in
            let gap = cal.dateComponents([.day], from: cal.startOfDay(for: day.date), to: dreamDay).day ?? 99
            guard (0...7).contains(gap) else { return nil }
            let other = Keywords(text: day.title + ". " + day.content, tags: day.tags)
            let (overlap, shared) = dreamKeys.overlap(with: other)
            let timeScore = [3, 2, 1, 1][safe: gap] ?? 0
            return Scored(item: day, score: overlap + timeScore, shared: shared, daysBefore: gap)
        }
        let relatedDays = scoredDays
            .filter { $0.score >= 4 || ($0.daysBefore == 0 && $0.score >= 3) }
            .sorted { $0.score > $1.score }
            .prefix(3)

        // 2) 相关过往梦境：只看内容和情绪
        let mine = Keywords(text: dream.title + ". " + dream.content, tags: dream.tags + dream.emotions)
        let scoredDreams: [Scored<DreamEntry>] = dreams.compactMap { other in
            guard other.id != dream.id, other.dreamDate < dream.dreamDate else { return nil }
            let keys = Keywords(text: other.title + ". " + other.content, tags: other.tags + other.emotions)
            let (overlap, shared) = mine.overlap(with: keys)
            let gap = cal.dateComponents([.day], from: cal.startOfDay(for: other.dreamDate), to: dreamDay).day ?? 0
            return Scored(item: other, score: overlap, shared: shared, daysBefore: gap)
        }
        let relatedDreams = scoredDreams.filter { $0.score >= 3 }.sorted { $0.score > $1.score }.prefix(2)

        // 3) 意象
        let fullText = dream.title + ". " + dream.content + " " + dream.tags.joined(separator: " ")
        let symbols = SymbolLexicon.entries
            .filter { e in e.keywords.contains { !Keyword.ranges(of: $0, in: fullText).isEmpty } }
            .prefix(4)

        // 4) 主题
        var themes: [String] = []
        for s in symbols where !themes.contains(s.theme) { themes.append(s.theme) }
        if themes.isEmpty { themes = ["Everyday fragments, reshuffled"] }
        themes = Array(themes.prefix(3))

        // 5) 文案
        let symbolNames = symbols.map { "“\($0.symbol.lowercased())”" }.joined(separator: ", ")
        var summary = symbols.isEmpty ? "“\(dream.title)”." : "“\(dream.title)” features \(symbolNames)."
        if let top = relatedDays.first {
            let clue = top.shared.prefix(3).joined(separator: ", ")
            summary += " Read alongside “\(top.item.title)” from \(when(top.daysBefore)), this dream is likely processing "
            summary += clue.isEmpty ? "feelings left over from the day." : "how you felt about \(clue)."
        } else {
            summary += " None of your recent day entries point to an obvious trigger. It may come from older memories."
        }
        if let pastDream = relatedDreams.first {
            summary += " It shares clues with “\(pastDream.item.title)” from \(pastDream.item.dreamDate.shortDay), so this theme seems to be coming back lately."
        }

        var tone = dream.emotions.isEmpty
            ? "The dream felt fairly neutral"
            : "The dream was mostly \(dream.emotions.map { $0.lowercased() }.joined(separator: " and "))"
        if let mood = relatedDays.first?.item.mood {
            let negativeDream = !Set(dream.emotions).isDisjoint(with: ["Uneasy", "Afraid", "Confused", "Sad"])
            let positiveDream = !Set(dream.emotions).isDisjoint(with: ["Joyful", "Free", "Excited", "Peaceful"])
            let label = mood.label.lowercased()
            if negativeDream, [.happy, .calm].contains(mood) {
                tone += ", in contrast to your \(label) mood that day. Worries hidden behind a good day can surface at night."
            } else if positiveDream, !negativeDream, [.stressed, .sad].contains(mood) {
                tone += ". You felt \(label) during the day, and this dream seems to be letting some of that pressure out."
            } else {
                tone += ", echoing your \(label) mood the day before."
            }
        } else {
            tone += "."
        }
        if dream.isLucid { tone += " You stayed aware inside the dream, which often goes with regaining a sense of control." }

        return DreamAnalysis(
            summary: summary,
            themes: themes,
            symbols: symbols.map { .init(symbol: $0.symbol, interpretation: $0.meaning) },
            relatedDays: relatedDays.map {
                .init(entryId: $0.item.id, date: $0.item.date, snippet: snippet($0.item.content),
                      reason: reason(daysBefore: $0.daysBefore, shared: $0.shared))
            },
            relatedDreams: relatedDreams.map {
                .init(entryId: $0.item.id, date: $0.item.dreamDate, snippet: snippet($0.item.content),
                      reason: daysAgo($0.daysBefore) + " earlier" + ($0.shared.isEmpty ? "" : " · Shared: " + $0.shared.prefix(3).joined(separator: ", ")))
            },
            emotionalTone: tone,
            suggestion: SymbolLexicon.suggestion(for: themes.first ?? ""),
            generatedAt: .now,
            source: .mock,
            model: "mock-local"
        )
    }

    private static func daysAgo(_ n: Int) -> String { n == 1 ? "1 day" : "\(n) days" }

    private static func when(_ daysBefore: Int) -> String {
        switch daysBefore {
        case 0: "the same day"
        case 1: "the day before"
        default: "\(daysBefore) days earlier"
        }
    }

    private static func reason(daysBefore: Int, shared: [String]) -> String {
        let time = daysBefore == 0 ? "Same day" : daysAgo(daysBefore) + " before"
        return shared.isEmpty ? time : time + " · Shared: " + shared.prefix(3).joined(separator: ", ")
    }

    private static func snippet(_ text: String) -> String {
        guard text.count > 60 else { return text }
        let cut = text.prefix(60)
        return (cut.lastIndex(of: " ").map { String(cut[..<$0]) } ?? String(cut)) + "…"
    }
}

// MARK: - 关键词（英文单词 + 标签）

private struct Keywords {
    var text: String
    var tags: [String]
    var words: [String: String]   // 词干 → 原文里第一次出现的写法（用于展示线索）

    /// 不参与匹配的常见词
    private static let stop: Set<String> = [
        "the", "and", "was", "were", "that", "this", "with", "for", "but", "had", "have", "has", "from", "into", "out",
        "all", "just", "then", "when", "what", "there", "they", "them", "she", "her", "his", "him", "you", "your", "our",
        "are", "not", "too", "very", "about", "after", "before", "still", "even", "felt", "feel", "like", "kept", "got",
        "get", "its", "one", "some", "could", "would", "should", "can", "did", "didn", "couldn", "really", "much", "more",
        "most", "over", "under", "down", "been", "being", "way", "back", "dream", "dreamed", "dreaming", "realized",
        "suddenly", "started", "decided", "myself", "everyone", "something", "thing", "things", "time", "day", "night",
        "who", "where", "which", "while", "than", "also", "only", "any", "each", "every", "here", "now", "though",
    ]

    init(text: String, tags: [String]) {
        self.text = text
        self.tags = tags
        words = Self.words(in: text)
    }

    static func stem(_ word: String) -> String {
        var w = word
        if w.hasSuffix("ies"), w.count > 4 { w = String(w.dropLast(3)) + "y" }
        else if w.hasSuffix("ing"), w.count > 5 { w = String(w.dropLast(3)) }
        else if w.hasSuffix("ed"), w.count > 4 { w = String(w.dropLast(2)) }
        else if w.hasSuffix("s"), !w.hasSuffix("ss"), w.count > 3 { w = String(w.dropLast()) }
        return w
    }

    static func words(in text: String) -> [String: String] {
        var result: [String: String] = [:]
        for raw in text.lowercased().split(whereSeparator: { !$0.isLetter }) {
            let w = String(raw)
            guard w.count >= 3, !stop.contains(w) else { continue }
            let s = stem(w)
            if result[s] == nil { result[s] = w }
        }
        return result
    }

    /// 返回 (分数, 共同线索)。共同标签记 3 分，共同单词记 1 分。
    func overlap(with other: Keywords) -> (Int, [String]) {
        var tagHits: [String] = []
        for t in tags where other.tags.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame })
            || !Keyword.ranges(of: t, in: other.text).isEmpty {
            if !tagHits.contains(t) { tagHits.append(t) }
        }
        for t in other.tags where !Keyword.ranges(of: t, in: text).isEmpty && !tagHits.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) {
            tagHits.append(t)
        }
        let sharedStems = Set(words.keys).intersection(other.words.keys)
        let score = tagHits.count * 3 + sharedStems.count

        // 已被标签覆盖的单词不再重复列出
        let tagStems = Set(tagHits.flatMap { Self.words(in: $0).keys })
        let sharedWords = sharedStems.subtracting(tagStems).compactMap { words[$0] }.sorted()
        return (score, tagHits.map { $0.lowercased() } + sharedWords)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

// MARK: - 意象词典

private enum SymbolLexicon {
    struct Entry {
        var symbol: String
        var keywords: [String]
        var meaning: String
        var theme: String
    }

    static let entries: [Entry] = [
        Entry(symbol: "Exam", keywords: ["exam", "test", "classroom"],
              meaning: "Often tied to the pressure of being judged: worrying you're not prepared or won't measure up.", theme: "Pressure & judgment"),
        Entry(symbol: "Falling", keywords: ["fall", "fell", "falling", "slipped"],
              meaning: "A classic image of losing control, common when an important outcome is pending.", theme: "Pressure & judgment"),
        Entry(symbol: "Flying", keywords: ["fly", "flying", "flew"],
              meaning: "Breaking free and feeling in control, or the lightness after pressure lifts.", theme: "Freedom & release"),
        Entry(symbol: "Water", keywords: ["water", "flood", "flooded", "underwater", "rain", "storm"],
              meaning: "Water stands for emotions; being surrounded by it often mirrors feeling overwhelmed lately.", theme: "Rising emotions"),
        Entry(symbol: "The sea", keywords: ["sea", "ocean"],
              meaning: "A wide, relaxed state of mind and openness to the unknown.", theme: "Freedom & release"),
        Entry(symbol: "Whale", keywords: ["whale"],
              meaning: "A vast, gentle force from deep inside, often showing up when you need to feel safe.", theme: "Freedom & release"),
        Entry(symbol: "Getting lost", keywords: ["lost", "can't find", "couldn't find", "couldn't read"],
              meaning: "A temporary loss of direction, common during big life changes.", theme: "Change & uncertainty"),
        Entry(symbol: "A strange city", keywords: ["city"],
              meaning: "Changes in your surroundings and relationships, and how you're adapting to them.", theme: "Change & uncertainty"),
        Entry(symbol: "Old house", keywords: ["old house", "house", "yard"],
              meaning: "Houses often stand for the self and past identity; an old house links to childhood, roots and belonging.", theme: "Nostalgia & belonging"),
        Entry(symbol: "Family", keywords: ["grandma", "grandpa", "mom", "dad", "mother", "father"],
              meaning: "Family members often appear when you need safety or care.", theme: "Nostalgia & belonging"),
        Entry(symbol: "Cracks", keywords: ["crack", "cracks", "collapse"],
              meaning: "Something familiar is changing; you may be bracing for a loss.", theme: "Change & uncertainty"),
        Entry(symbol: "Dead phone", keywords: ["phone was dead", "no signal", "battery"],
              meaning: "Losing touch with others, and worrying about being alone somewhere new.", theme: "Change & uncertainty"),
        Entry(symbol: "Being chased", keywords: ["chase", "chased", "running away"],
              meaning: "You may be avoiding something you need to face.", theme: "Pressure & judgment"),
        Entry(symbol: "Door", keywords: ["door"],
              meaning: "An entrance to a new stage, standing for choices and opportunities.", theme: "Change & uncertainty"),
    ]

    static func suggestion(for theme: String) -> String {
        switch theme {
        case "Pressure & judgment": "Break whatever is stressing you into a few small written steps, and try five minutes of slow breathing before bed to tell your brain it's been handled."
        case "Freedom & release": "This is a good sign. Notice the people and things that have helped you feel lighter lately, and make more room for them."
        case "Rising emotions": "Your feelings may be running high. Talk to someone you trust, or pour it out in your journal."
        case "Change & uncertainty": "Feeling uneasy during change is normal. List three small things you're looking forward to in the new place to give the uncertainty an anchor."
        case "Nostalgia & belonging": "Old memories are pointing at what matters to you. Call a family member or go through some old photos."
        default: "Keep logging your days and dreams. The more you write, the more patterns the analysis can find."
        }
    }
}
