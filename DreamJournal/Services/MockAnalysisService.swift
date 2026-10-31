import Foundation

/// 本地模拟后端：时间窗口 + 关键词重叠检索相关日记，再用模板和意象词典生成报告。
/// 返回的结构与真实后端完全一致，方便离线演示。
struct MockAnalysisService: AnalysisService {
    var latency: Duration = .milliseconds(1600)

    func sync(days: [DayEntry], dreams: [DreamEntry]) async throws {}

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
        let dreamKeys = Keywords(text: dream.title + dream.content, tags: dream.tags)

        // 1) 相关白天：梦之前 7 天内，时间越近、共同线索越多分越高
        let scoredDays: [Scored<DayEntry>] = days.compactMap { day in
            let gap = cal.dateComponents([.day], from: cal.startOfDay(for: day.date), to: dreamDay).day ?? 99
            guard (0...7).contains(gap) else { return nil }
            let other = Keywords(text: day.title + day.content, tags: day.tags)
            let (overlap, shared) = dreamKeys.overlap(with: other)
            let timeScore = [3, 2, 1, 1][safe: gap] ?? 0
            return Scored(item: day, score: overlap + timeScore, shared: shared, daysBefore: gap)
        }
        let relatedDays = scoredDays
            .filter { $0.score >= 3 || ($0.daysBefore == 0 && $0.score >= 2) }
            .sorted { $0.score > $1.score }
            .prefix(3)

        // 2) 相关过往梦境：只看内容和情绪
        let scoredDreams: [Scored<DreamEntry>] = dreams.compactMap { other in
            guard other.id != dream.id, other.dreamDate < dream.dreamDate else { return nil }
            let keys = Keywords(text: other.title + other.content, tags: other.tags + other.emotions)
            let mine = Keywords(text: dream.title + dream.content, tags: dream.tags + dream.emotions)
            let (overlap, shared) = mine.overlap(with: keys)
            let gap = cal.dateComponents([.day], from: cal.startOfDay(for: other.dreamDate), to: dreamDay).day ?? 0
            return Scored(item: other, score: overlap, shared: shared, daysBefore: gap)
        }
        let relatedDreams = scoredDreams.filter { $0.score >= 3 }.sorted { $0.score > $1.score }.prefix(2)

        // 3) 意象
        let fullText = dream.title + dream.content + dream.tags.joined()
        let symbols = SymbolLexicon.entries.filter { e in e.keywords.contains { fullText.contains($0) } }.prefix(4)

        // 4) 主题
        var themes: [String] = []
        for s in symbols where !themes.contains(s.theme) { themes.append(s.theme) }
        if themes.isEmpty { themes = ["日常片段的重组"] }
        themes = Array(themes.prefix(3))

        // 5) 文案
        let symbolNames = symbols.map { "「\($0.symbol)」" }.joined(separator: "、")
        var summary = symbols.isEmpty ? "「\(dream.title)」" : "「\(dream.title)」里出现了\(symbolNames)等意象。"
        if let top = relatedDays.first {
            let clue = top.shared.prefix(3).joined(separator: "、")
            summary += "结合你\(when(top.daysBefore))记录的「\(top.item.title)」，这个梦很可能在消化白天"
            summary += clue.isEmpty ? "留下的情绪。" : "关于「\(clue)」的感受。"
        } else {
            summary += "最近的白天日记里没有找到明显的直接线索，它也许来自更久远的记忆。"
        }
        if let pastDream = relatedDreams.first {
            summary += "它和 \(pastDream.item.dreamDate.shortDay) 的梦「\(pastDream.item.title)」有相似的线索，说明这一主题近期在反复出现。"
        }

        var tone = dream.emotions.isEmpty ? "梦中的情绪比较平淡" : "梦中以「\(dream.emotions.joined(separator: "、"))」为主"
        if let mood = relatedDays.first?.item.mood {
            let negativeDream = !Set(dream.emotions).isDisjoint(with: ["不安", "恐惧", "困惑", "悲伤"])
            let positiveDream = !Set(dream.emotions).isDisjoint(with: ["愉快", "自由", "兴奋", "平静"])
            if negativeDream, [.happy, .calm].contains(mood) {
                tone += "，和白天「\(mood.label)」的心情形成反差：白天被喜悦或平静盖住的担忧，可能在夜里浮现出来。"
            } else if positiveDream, !negativeDream, [.stressed, .sad].contains(mood) {
                tone += "。白天的你有些「\(mood.label)」，这个梦像是在帮你释放积攒的压力。"
            } else {
                tone += "，与梦前白天「\(mood.label)」的心情相互呼应。"
            }
        } else {
            tone += "。"
        }
        if dream.isLucid { tone += "你在梦中保持了清醒，这通常意味着你正在重新获得掌控感。" }

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
                      reason: "\($0.daysBefore) 天前的梦" + ($0.shared.isEmpty ? "" : " · 共同线索：" + $0.shared.prefix(3).joined(separator: "、")))
            },
            emotionalTone: tone,
            suggestion: SymbolLexicon.suggestion(for: themes.first ?? ""),
            generatedAt: .now,
            source: .mock,
            model: "mock-local"
        )
    }

    private static func when(_ daysBefore: Int) -> String {
        switch daysBefore {
        case 0: "当天"
        case 1: "前一天"
        default: "\(daysBefore) 天前"
        }
    }

    private static func reason(daysBefore: Int, shared: [String]) -> String {
        let time = daysBefore == 0 ? "梦的当天" : "梦前 \(daysBefore) 天"
        return shared.isEmpty ? time : time + " · 共同线索：" + shared.prefix(3).joined(separator: "、")
    }

    private static func snippet(_ text: String) -> String {
        text.count > 40 ? String(text.prefix(40)) + "…" : text
    }
}

// MARK: - 关键词（中文 2-gram + 标签）

private struct Keywords {
    var text: String
    var tags: Set<String>
    var grams: Set<String>

    /// 含这些虚词的 2-gram 不参与匹配（“我一”“上的”之类没有意义）
    private static let functionChars = Set("的了我你他她它在是一着过很就都也又还和与把被上下里个有不这那们到来去说要会能对得地让给从却已才再么吗呢吧啊每")
    private static let stop: Set<String> = ["梦见", "梦里", "觉得", "突然", "发现", "出现", "开始", "最后", "然后", "一直", "已经", "怎么", "什么", "时候", "自己"]

    init(text: String, tags: [String]) {
        self.text = text
        self.tags = Set(tags)
        grams = Self.grams(in: text)
    }

    static func grams(in text: String) -> Set<String> {
        let chars = Array(text)
        var result = Set<String>()
        for i in 0..<max(chars.count - 1, 0) {
            let a = chars[i], b = chars[i + 1]
            guard a.isCJK, b.isCJK, !functionChars.contains(a), !functionChars.contains(b) else { continue }
            let g = String([a, b])
            if !stop.contains(g) { result.insert(g) }
        }
        return result
    }

    /// 返回 (分数, 共同线索)。共同标签记 3 分，共同 2-gram 记 1 分；
    /// 线索展示时把相邻的共同 2-gram 合并成完整词（“陌生”+“生城”+“城市” → “陌生城市”）。
    func overlap(with other: Keywords) -> (Int, [String]) {
        let tagHits = tags.filter { other.tags.contains($0) || other.text.contains($0) }
            .union(other.tags.filter { text.contains($0) })
        let sharedGrams = grams.intersection(other.grams)
        let score = tagHits.count * 3 + sharedGrams.count

        var phrases: [String] = []
        let chars = Array(text)
        var i = 0
        while i < chars.count - 1 {
            guard sharedGrams.contains(String([chars[i], chars[i + 1]])) else { i += 1; continue }
            var j = i + 1
            while j < chars.count - 1, sharedGrams.contains(String([chars[j], chars[j + 1]])) { j += 1 }
            let phrase = String(chars[i...j])
            if !phrases.contains(phrase) { phrases.append(phrase) }
            i = j + 1
        }
        // 被标签包含的短语去掉；被更长短语包含的标签也去掉（保留“陌生城市”而不是“城市”）
        let keptPhrases = phrases.filter { p in !tagHits.contains { $0.contains(p) } }
        let keptTags = tagHits.sorted().filter { t in !keptPhrases.contains { $0.contains(t) } }
        let clues = keptTags + keptPhrases
        return (score, clues)
    }
}

private extension Character {
    var isCJK: Bool {
        unicodeScalars.allSatisfy { (0x4E00...0x9FFF).contains($0.value) }
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
        Entry(symbol: "考试", keywords: ["考试", "考场", "教室", "试卷"], meaning: "常对应“被评估”的压力：你担心自己准备得不够、不被认可。", theme: "压力与评价"),
        Entry(symbol: "坠落", keywords: ["掉", "坠", "滑"], meaning: "失控感的典型象征，往往出现在面临重要结果、担心失败的时期。", theme: "压力与评价"),
        Entry(symbol: "飞翔", keywords: ["飞"], meaning: "代表摆脱束缚、掌控感提升，也可能是压力释放后的轻松。", theme: "自由与释放"),
        Entry(symbol: "水", keywords: ["水", "淹", "雨"], meaning: "水象征情绪的流动；被水包围常对应近期被某种情绪或环境“淹没”的感受。", theme: "情绪涌动"),
        Entry(symbol: "海", keywords: ["海"], meaning: "广阔的潜意识与放松状态，也意味着对未知的开放。", theme: "自由与释放"),
        Entry(symbol: "鲸鱼", keywords: ["鲸"], meaning: "潜意识深处庞大而温和的力量，常在你需要安全感时出现。", theme: "自由与释放"),
        Entry(symbol: "迷路", keywords: ["迷路", "找不到", "看不懂"], meaning: "方向感暂时缺失，通常出现在生活面临转变、需要重新定位的时候。", theme: "转变与不确定"),
        Entry(symbol: "陌生城市", keywords: ["城市"], meaning: "代表外部环境和社会关系的变化，以及你对新环境的适应。", theme: "转变与不确定"),
        Entry(symbol: "老房子", keywords: ["老房子", "房子", "屋子", "院子"], meaning: "房子常象征自我与过去的身份；老房子与童年、根源和归属感相连。", theme: "怀旧与归属"),
        Entry(symbol: "家人", keywords: ["奶奶", "爷爷", "妈妈", "爸爸"], meaning: "亲人的出现往往和安全感、被照顾的需要有关。", theme: "怀旧与归属"),
        Entry(symbol: "裂缝", keywords: ["裂缝", "裂开", "倒塌"], meaning: "熟悉的事物正在发生变化，你可能在为某种“失去”做心理准备。", theme: "转变与不确定"),
        Entry(symbol: "手机没电", keywords: ["没电", "信号"], meaning: "与他人的连接中断，担心在新环境里孤立无援。", theme: "转变与不确定"),
        Entry(symbol: "追逐", keywords: ["追", "逃"], meaning: "你可能在回避某件需要面对的事。", theme: "压力与评价"),
        Entry(symbol: "门", keywords: ["门"], meaning: "通往新阶段的入口，象征选择与机会。", theme: "转变与不确定"),
    ]

    static func suggestion(for theme: String) -> String {
        switch theme {
        case "压力与评价": "试着把让你紧张的事情拆成几个小步骤写下来，睡前做 5 分钟呼吸放松，给大脑一个“已经处理过”的信号。"
        case "自由与释放": "这是一个积极的信号。留意最近让你感到轻松的人和事，有意识地给自己多留一些这样的时间。"
        case "情绪涌动": "最近情绪可能比较满，可以找一个信任的人聊聊，或者用写日记的方式把感受倒出来。"
        case "转变与不确定": "面对变化时的不安很正常。列出新环境里你期待的三件小事，给不确定感一些具体的锚点。"
        case "怀旧与归属": "过去的记忆在提醒你什么对你重要。给家人打个电话，或者整理一下老照片，都是很好的连接方式。"
        default: "继续记录白天和梦境，积累得越多，联合分析就越能看出你的模式。"
        }
    }
}
