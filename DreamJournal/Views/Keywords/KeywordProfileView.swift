import SwiftUI

/// 关键词档案：介绍、别名、备注、提到它的梦（反向链接），以及常一起出现的关键词
struct KeywordProfileView: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let keywordID: UUID

    @State private var editing = false
    @State private var confirmDelete = false

    var body: some View {
        ZStack {
            NightPalette.backgroundGradient.ignoresSafeArea()
            StarfieldView(starCount: 50).ignoresSafeArea()

            if let keyword = store.keyword(id: keywordID) {
                let dreams = store.dreams(mentioning: keyword)
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header(keyword, count: dreams.count)
                        if !keyword.note.isEmpty { noteCard(keyword.note) }
                        stats(dreams)
                        backlinks(keyword, dreams: dreams)
                        related(keyword, dreams: dreams)
                    }
                    .padding(16)
                    .padding(.bottom, 24)
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button("Edit", systemImage: "pencil") { editing = true }
                            Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete = true }
                        } label: { Label("More", systemImage: "ellipsis.circle") }
                    }
                }
                .sheet(isPresented: $editing) { KeywordEditView(existing: keyword) }
                .confirmationDialog("Delete “\(keyword.name)”?", isPresented: $confirmDelete, titleVisibility: .visible) {
                    Button("Delete", role: .destructive) {
                        dismiss()
                        store.deleteKeyword(id: keywordID)
                    }
                } message: { Text("Only the keyword is deleted. Your dreams stay as they are.") }
            } else {
                ContentUnavailableView("Keyword deleted", systemImage: "tag.slash")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .tint(NightPalette.accent)
    }

    private func header(_ keyword: Keyword, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: keyword.kind.icon)
                    .font(.title2)
                    .foregroundStyle(keyword.kind.color)
                    .frame(width: 56, height: 56)
                    .background(keyword.kind.color.opacity(0.16), in: Circle())
                    .overlay(Circle().strokeBorder(keyword.kind.color.opacity(0.4), lineWidth: 1))
                VStack(alignment: .leading, spacing: 4) {
                    Text(keyword.name)
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(NightPalette.text)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    Text(keyword.kind.label)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(keyword.kind.color.opacity(0.18), in: Capsule())
                        .foregroundStyle(keyword.kind.color)
                }
            }
            if !keyword.subtitle.isEmpty {
                Text(keyword.subtitle)
                    .font(.body)
                    .foregroundStyle(NightPalette.text.opacity(0.85))
            }
            if !keyword.aliases.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Also")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NightPalette.secondaryText)
                    FlowLayout(spacing: 6) {
                        ForEach(keyword.aliases, id: \.self) { alias in
                            Text(alias)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(NightPalette.chip, in: Capsule())
                                .foregroundStyle(NightPalette.text)
                        }
                    }
                }
            }
        }
    }

    private func noteCard(_ note: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Notes", systemImage: "note.text")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NightPalette.accent)
            Text(note)
                .font(.body)
                .lineSpacing(5)
                .foregroundStyle(NightPalette.text)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .journalCard(.night, shadow: false)
    }

    private func stats(_ dreams: [DreamEntry]) -> some View {
        HStack(spacing: 10) {
            statTile(value: "\(dreams.count)", label: dreams.count == 1 ? "dream" : "dreams")
            statTile(value: dreams.last.map { $0.dreamDate.shortDay } ?? "—", label: "First seen")
            statTile(value: dreams.first.map { $0.dreamDate.shortDay } ?? "—", label: "Last seen")
        }
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(NightPalette.text)
            Text(label)
                .font(.caption)
                .foregroundStyle(NightPalette.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(NightPalette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func backlinks(_ keyword: Keyword, dreams: [DreamEntry]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dreams that mention it")
                .font(.title3.weight(.bold))
                .foregroundStyle(NightPalette.text)
                .padding(.leading, 4)
                .accessibilityAddTraits(.isHeader)
            if dreams.isEmpty {
                Text("No dreams mention “\(keyword.name)” yet. Tap it during quick capture and the dream will link here.")
                    .font(.subheadline)
                    .foregroundStyle(NightPalette.secondaryText)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(NightPalette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(dreams.enumerated()), id: \.element.id) { index, dream in
                        NavigationLink(value: Route.dream(dream.id)) {
                            DreamNoteRow(dream: dream, dateLabel: dream.dreamDate.shortDay)
                        }
                        .buttonStyle(NoteRowButtonStyle())
                        if index < dreams.count - 1 {
                            Rectangle().fill(NightPalette.separator).frame(height: 0.5).padding(.leading, 16)
                        }
                    }
                }
                .background(NightPalette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    /// 和它出现在同一个梦里的其他关键词，按共同出现次数排序
    @ViewBuilder
    private func related(_ keyword: Keyword, dreams: [DreamEntry]) -> some View {
        let counts = dreams.reduce(into: [UUID: Int]()) { acc, dream in
            for other in store.keywords(in: dream) where other.id != keyword.id { acc[other.id, default: 0] += 1 }
        }
        let others = counts.keys.compactMap { store.keyword(id: $0) }
            .sorted { counts[$0.id]! != counts[$1.id]! ? counts[$0.id]! > counts[$1.id]! : $0.name < $1.name }
        if !others.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Often appears with")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(NightPalette.text)
                    .padding(.leading, 4)
                    .accessibilityAddTraits(.isHeader)
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(others) { other in
                        NavigationLink(value: Route.keyword(other.id)) {
                            HStack(spacing: 4) {
                                KeywordChip(name: other.name, kind: other.kind)
                                Text("×\(counts[other.id]!)")
                                    .font(.caption.weight(.semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(NightPalette.secondaryText)
                            }
                        }
                        .buttonStyle(PressableCardStyle())
                        .accessibilityLabel("\(other.name), together \(counts[other.id]!) times")
                    }
                }
            }
        }
    }
}
