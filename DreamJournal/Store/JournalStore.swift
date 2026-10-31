import Foundation
import Observation

/// 本地数据仓库：白天日记 + 梦境日记，以 JSON 存在 Documents 目录。
@Observable
final class JournalStore {
    private(set) var dayEntries: [DayEntry] = []
    private(set) var dreamEntries: [DreamEntry] = []

    private struct Snapshot: Codable {
        var days: [DayEntry]
        var dreams: [DreamEntry]
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
        return true
    }

    private func save() {
        let snapshot = Snapshot(days: dayEntries, dreams: dreamEntries)
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
