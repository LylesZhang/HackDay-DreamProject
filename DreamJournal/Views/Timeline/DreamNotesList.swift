import SwiftUI

/// 夜间模式的梦境列表：仿“备忘录”按时间分组（今天 / 昨天 / 过去 7 天 / 过去 30 天 / 月份 / 年份），
/// 顶部标签栏可按 tag 筛选。
struct DreamNotesList: View {
    @Environment(JournalStore.self) private var store
    @State private var selectedTag: String?
    @State private var pendingDelete: DreamEntry?

    private var filtered: [DreamEntry] {
        guard let selectedTag else { return store.sortedDreams }
        return store.sortedDreams.filter { $0.tags.contains(selectedTag) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if !tagCounts.isEmpty { tagBar }

            if store.dreamEntries.isEmpty {
                ContentUnavailableView {
                    Label("No dreams yet", systemImage: "moon.zzz").foregroundStyle(NightPalette.text)
                } description: {
                    Text("Write one down as soon as you wake up.").foregroundStyle(NightPalette.secondaryText)
                }
                .padding(.top, 40)
            } else {
                LazyVStack(alignment: .leading, spacing: 22) {
                    ForEach(DreamSection.make(from: filtered)) { section in
                        sectionView(section)
                    }
                }
                .animation(.snappy, value: selectedTag)
            }
        }
        .sensoryFeedback(.selection, trigger: selectedTag)
        .confirmationDialog("Delete this dream?", isPresented: Binding(get: { pendingDelete != nil },
                                                             set: { if !$0 { pendingDelete = nil } }),
                            titleVisibility: .visible, presenting: pendingDelete) { dream in
            Button("Delete", role: .destructive) { store.deleteDream(id: dream.id) }
        } message: { _ in Text("Its AI report will be deleted too. This can't be undone.") }
    }

    // MARK: - 标签栏

    /// 按使用次数排序的标签
    private var tagCounts: [(tag: String, count: Int)] {
        var counts: [String: Int] = [:]
        for dream in store.dreamEntries { for tag in Set(dream.tags) { counts[tag, default: 0] += 1 } }
        return counts.map { ($0.key, $0.value) }.sorted { $0.count != $1.count ? $0.count > $1.count : $0.tag < $1.tag }
    }

    private var tagBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                tagButton(title: "All", count: store.dreamEntries.count, isOn: selectedTag == nil) { selectedTag = nil }
                ForEach(tagCounts, id: \.tag) { item in
                    tagButton(title: "#\(item.tag)", count: item.count, isOn: selectedTag == item.tag) {
                        selectedTag = selectedTag == item.tag ? nil : item.tag
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -16)   // 让标签栏横向贯穿屏幕边缘
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Filter by tag")
    }

    private func tagButton(title: String, count: Int, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(title).font(.subheadline.weight(.semibold))
                Text("\(count)").font(.caption.weight(.semibold)).monospacedDigit().opacity(0.6)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isOn ? AnyShapeStyle(NightPalette.accent) : AnyShapeStyle(NightPalette.surface), in: Capsule())
            .overlay(Capsule().strokeBorder(NightPalette.accent.opacity(isOn ? 0 : 0.25), lineWidth: 1))
            .foregroundStyle(isOn ? NightPalette.ink : NightPalette.text)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(count) \(count == 1 ? "dream" : "dreams")")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    // MARK: - 分组

    private func sectionView(_ section: DreamSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.title)
                .font(.title3.weight(.bold))
                .foregroundStyle(NightPalette.text)
                .padding(.leading, 4)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0) {
                ForEach(Array(section.entries.enumerated()), id: \.element.id) { index, dream in
                    NavigationLink(value: Route.dream(dream.id)) {
                        DreamNoteRow(dream: dream, dateLabel: section.rowLabel(for: dream))
                    }
                    .buttonStyle(NoteRowButtonStyle())
                    .contextMenu {
                        Button("Delete", systemImage: "trash", role: .destructive) { pendingDelete = dream }
                    }
                    if index < section.entries.count - 1 {
                        Rectangle()
                            .fill(NightPalette.separator)
                            .frame(height: 0.5)
                            .padding(.leading, 16)
                    }
                }
            }
            .background(NightPalette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

/// 备忘录风格的一行：标题 / 日期 + 摘要 / 标签
struct DreamNoteRow: View {
    let dream: DreamEntry
    let dateLabel: String

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(dream.title)
                    .font(.headline)
                    .foregroundStyle(NightPalette.text)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(dateLabel)
                        .foregroundStyle(NightPalette.text.opacity(0.85))
                    Text(dream.content)
                        .foregroundStyle(NightPalette.secondaryText)
                }
                .font(.subheadline)
                .lineLimit(1)
                if !dream.tags.isEmpty {
                    Label(dream.tags.prefix(3).joined(separator: " · "), systemImage: "number")
                        .font(.caption)
                        .foregroundStyle(NightPalette.secondaryText.opacity(0.8))
                        .labelStyle(TightLabelStyle())
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                if dream.isLucid { Image(systemName: "eye").accessibilityLabel("Lucid") }
                if dream.analysis != nil { Image(systemName: "sparkles").accessibilityLabel("Analyzed") }
            }
            .font(.footnote)
            .foregroundStyle(NightPalette.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

private struct TightLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) { configuration.icon.imageScale(.small); configuration.title }
    }
}

/// 列表行的按压高亮（模拟系统 List 的点按效果）
struct NoteRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.white.opacity(configuration.isPressed ? 0.08 : 0))
    }
}

/// 一个时间分组
struct DreamSection: Identifiable {
    enum Kind: Equatable { case today, yesterday, week, month, calendarMonth, year }

    let id: String
    let title: String
    let kind: Kind
    var entries: [DreamEntry]

    /// 行内的日期：今天 / 昨天显示记录时间，一周内显示星期，更早显示日期
    func rowLabel(for dream: DreamEntry) -> String {
        switch kind {
        case .today, .yesterday: dream.recordedAt.formatted(.dateTime.hour().minute().locale(Date.appLocale))
        case .week: dream.dreamDate.formatted(.dateTime.weekday(.wide).locale(Date.appLocale))
        default: dream.dreamDate.shortDay
        }
    }

    static func make(from dreams: [DreamEntry], now: Date = .now, calendar cal: Calendar = .current) -> [DreamSection] {
        let today = cal.startOfDay(for: now)
        var sections: [DreamSection] = []
        for dream in dreams.sorted(by: { $0.dreamDate > $1.dreamDate }) {
            let day = cal.startOfDay(for: dream.dreamDate)
            let ago = cal.dateComponents([.day], from: day, to: today).day ?? 0
            let (id, title, kind): (String, String, Kind) = switch ago {
            case ..<1: ("today", "Today", .today)
            case 1: ("yesterday", "Yesterday", .yesterday)
            case 2..<7: ("week", "Previous 7 Days", .week)
            case 7..<30: ("month", "Previous 30 Days", .month)
            default:
                if cal.isDate(dream.dreamDate, equalTo: now, toGranularity: .year) {
                    ("m-\(cal.component(.month, from: day))", day.formatted(.dateTime.month(.wide).locale(Date.appLocale)), .calendarMonth)
                } else {
                    ("y-\(cal.component(.year, from: day))", "\(cal.component(.year, from: day))", .year)
                }
            }
            // 已按日期倒序，同组条目必然相邻
            if sections.last?.id == id {
                sections[sections.count - 1].entries.append(dream)
            } else {
                sections.append(DreamSection(id: id, title: title, kind: kind, entries: [dream]))
            }
        }
        return sections
    }
}
