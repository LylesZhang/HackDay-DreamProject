import Foundation
import Observation

/// 本地数据仓库：白天日记 + 梦境日记，以 JSON 存在 Documents 目录。
@Observable
final class JournalStore {
    private(set) var dayEntries: [DayEntry] = []
    private(set) var dreamEntries: [DreamEntry] = []
    private(set) var keywords: [Keyword] = []
    /// AI 从最近几天的梦里提炼的关键词，下次速记时弹出
    private(set) var keywordSuggestions: KeywordSuggestionBatch?
    private var isRefreshingSuggestions = false

    private struct Snapshot: Codable {
        var days: [DayEntry]
        var dreams: [DreamEntry]
        // 新增字段用可选类型，旧版本存档也能正常读取
        var keywords: [Keyword]?
        var keywordSuggestions: KeywordSuggestionBatch?
    }

    private let fileURL: URL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("journal.json")

    init() {
        if ProcessInfo.processInfo.arguments.contains("-resetData") || !load() {
            resetToSampleData()
        }
    }

    // MARK: - Queries

    var sortedDays: [DayEntry] { dayEntries.sorted { $0.date > $1.date } }
    var sortedDreams: [DreamEntry] { dreamEntries.sorted { $0.dreamDate > $1.dreamDate } }

    func day(id: UUID) -> DayEntry? { dayEntries.first { $0.id == id } }
    func dream(id: UUID) -> DreamEntry? { dreamEntries.first { $0.id == id } }

    /// 按日期分组的“昼夜双卡”数据，新的在前。
    var dayNightPairs: [DayNightPair] {
        let cal = Calendar.current
        var map: [Date: DayNightPair] = [:]
        for d in dayEntries {
            let key = cal.startOfDay(for: d.date)
            map[key, default: DayNightPair(date: key)].day = d
        }
        for d in dreamEntries {
            let key = cal.startOfDay(for: d.dreamDate)
            map[key, default: DayNightPair(date: key)].dream = d
        }
        return map.values.sorted { $0.date > $1.date }
    }

    // MARK: - Keywords

    func keyword(id: UUID) -> Keyword? { keywords.first { $0.id == id } }

    func keywords(of kind: Keyword.Kind) -> [Keyword] {
        keywords.filter { $0.kind == kind }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// 名字或别名与 `name` 相同的关键词（不区分大小写）
    func keyword(matching name: String) -> Keyword? {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else { return nil }
        return keywords.first { $0.terms.contains { $0.caseInsensitiveCompare(n) == .orderedSame } }
    }

    /// 一个梦里提到的关键词（双链：正文、标题或标签里出现名字 / 别名）
    func keywords(in dream: DreamEntry) -> [Keyword] {
        let text = dream.title + "\n" + dream.content + "\n" + dream.tags.joined(separator: " ")
        return keywords.filter { $0.isMentioned(in: text) }
    }

    /// 提到某个关键词的梦（反向链接），新的在前
    func dreams(mentioning keyword: Keyword) -> [DreamEntry] {
        sortedDreams.filter { keywords(in: $0).contains { $0.id == keyword.id } }
    }

    func upsert(_ keyword: Keyword) {
        if let i = keywords.firstIndex(where: { $0.id == keyword.id }) {
            var updated = keyword
            // 改名时把旧名字留作别名，已经写过旧名字的梦仍然链接得上
            let old = keywords[i].name
            if old != updated.name, !updated.aliases.contains(old) { updated.aliases.append(old) }
            keywords[i] = updated
        } else {
            keywords.append(keyword)
        }
        save()
    }

    func deleteKeyword(id: UUID) {
        keywords.removeAll { $0.id == id }
        save()
    }

    // MARK: - AI keyword suggestions

    /// 最近几天梦境内容的稳定签名；内容变化后才需要重新提炼
    var suggestionSignature: String {
        let recent = KeywordExtractor.recentDreams(dreamEntries)
        var hash: UInt64 = 5381
        for byte in recent.map({ $0.id.uuidString + $0.title + $0.content + $0.tags.joined() }).joined().utf8 {
            hash = (hash &* 33) &+ UInt64(byte)
        }
        return "\(recent.count)-\(hash)"
    }

    /// 建议里还没收进关键词库的
    var newKeywordSuggestions: [KeywordSuggestion] {
        (keywordSuggestions?.suggestions ?? []).filter { keyword(matching: $0.name) == nil }
    }

    @MainActor
    func refreshKeywordSuggestions(using service: AnalysisService) async {
        let signature = suggestionSignature
        guard !isRefreshingSuggestions, keywordSuggestions?.basedOn != signature else { return }
        let recent = KeywordExtractor.recentDreams(dreamEntries)
        guard !recent.isEmpty else {
            keywordSuggestions = nil
            save()
            return
        }
        isRefreshingSuggestions = true
        defer { isRefreshingSuggestions = false }

        var source: DreamAnalysis.Source = service is RemoteAnalysisService ? .gemini : .mock
        var suggestions: [KeywordSuggestion]
        do {
            suggestions = try await service.suggestKeywords(recentDreams: recent, existing: keywords)
        } catch {
            // 后端不可用时退回本地提炼，速记页照样有建议可点
            print("Keyword suggestion failed, using local extractor: \(error)")
            suggestions = KeywordExtractor.suggest(recentDreams: recent, existing: keywords)
            source = .mock
        }
        keywordSuggestions = KeywordSuggestionBatch(suggestions: suggestions, generatedAt: .now,
                                                    basedOn: signature, source: source)
        save()
    }

    // MARK: - Mutations

    func upsert(_ entry: DayEntry) {
        if let i = dayEntries.firstIndex(where: { $0.id == entry.id }) {
            dayEntries[i] = entry
        } else {
            dayEntries.append(entry)
        }
        save()
    }

    func upsert(_ entry: DreamEntry) {
        if let i = dreamEntries.firstIndex(where: { $0.id == entry.id }) {
            dreamEntries[i] = entry
        } else {
            dreamEntries.append(entry)
        }
        save()
    }

    func deleteDay(id: UUID) {
        dayEntries.removeAll { $0.id == id }
        save()
    }

    func deleteDream(id: UUID) {
        dreamEntries.removeAll { $0.id == id }
        save()
    }

    func attach(_ analysis: DreamAnalysis, toDream id: UUID) {
        guard let i = dreamEntries.firstIndex(where: { $0.id == id }) else { return }
        dreamEntries[i].analysis = analysis
        save()
    }

    func resetToSampleData() {
        let sample = SampleData.make()
        dayEntries = sample.days
        dreamEntries = sample.dreams
        keywords = SampleData.keywords()
        keywordSuggestions = nil
        save()
    }

    // MARK: - Persistence

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    @discardableResult
    private func load() -> Bool {
        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? Self.decoder.decode(Snapshot.self, from: data) else { return false }
        dayEntries = snapshot.days
        dreamEntries = snapshot.dreams
        keywords = snapshot.keywords ?? []
        keywordSuggestions = snapshot.keywordSuggestions
        return true
    }

    private func save() {
        let snapshot = Snapshot(days: dayEntries, dreams: dreamEntries,
                                keywords: keywords, keywordSuggestions: keywordSuggestions)
        do {
            try Self.encoder.encode(snapshot).write(to: fileURL, options: .atomic)
        } catch {
            print("JournalStore save failed: \(error)")
        }
    }
}

struct DayNightPair: Identifiable {
    var date: Date
    var day: DayEntry?
    var dream: DreamEntry?
    var id: Date { date }
}
