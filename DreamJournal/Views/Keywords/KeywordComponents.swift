import SwiftUI

/// 关键词胶囊：类型图标 + 名字，颜色区分人物 / 意象 / 场景
struct KeywordChip: View {
    let name: String
    let kind: Keyword.Kind
    var isOn = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: isOn ? "checkmark" : kind.icon)
                .font(.caption2.weight(.bold))
                .foregroundStyle(isOn ? NightPalette.ink : kind.color)
            Text(name)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .foregroundStyle(isOn ? NightPalette.ink : NightPalette.text)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(isOn ? AnyShapeStyle(kind.color) : AnyShapeStyle(kind.color.opacity(0.14)), in: Capsule())
        .overlay(Capsule().strokeBorder(kind.color.opacity(isOn ? 0 : 0.4), lineWidth: 1))
        .contentShape(Capsule())
    }
}

/// 虚线“＋ 新建”胶囊
struct NewKeywordChip: View {
    var title = "New"

    var body: some View {
        Label(title, systemImage: "plus")
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .foregroundStyle(NightPalette.secondaryText)
            .overlay(Capsule().strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .foregroundStyle(NightPalette.secondaryText.opacity(0.6)))
            .contentShape(Capsule())
    }
}

/// 速记 / 编辑页里的关键词面板：按类型分组，点一下把关键词写进记录
struct KeywordPicker: View {
    @Environment(JournalStore.self) private var store
    var isUsed: (Keyword) -> Bool
    var onPick: (Keyword) -> Void
    @State private var creating: Keyword.Kind?
    @State private var picks = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Keyword.Kind.allCases) { kind in
                VStack(alignment: .leading, spacing: 8) {
                    Label(kind.label, systemImage: kind.icon)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(NightPalette.secondaryText)
                        .accessibilityAddTraits(.isHeader)
                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(store.keywords(of: kind)) { keyword in
                            let used = isUsed(keyword)
                            Button {
                                picks += 1
                                onPick(keyword)
                            } label: {
                                KeywordChip(name: keyword.name, kind: keyword.kind, isOn: used)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("\(kind.shortLabel): \(keyword.name)")
                            .accessibilityHint(used ? "Already in your notes. Tap to add it again." : "Adds it to your notes")
                            .accessibilityAddTraits(used ? .isSelected : [])
                        }
                        Button { creating = kind } label: { NewKeywordChip() }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("New \(kind.shortLabel.lowercased())")
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .sensoryFeedback(.selection, trigger: picks)
        .sheet(item: $creating) { kind in KeywordEditView(newKind: kind) }
    }
}

/// 速记页顶部弹出的 AI 建议
struct KeywordSuggestionCard: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let batch: KeywordSuggestionBatch
    var isUsed: (String) -> Bool
    var onPick: (KeywordSuggestion) -> Void
    var onDismiss: () -> Void

    @State private var appeared = false
    @State private var saved = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("Recurring in the last \(KeywordExtractor.lookbackDays) days", systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NightPalette.accent)
                    .symbolEffect(.pulse, options: .repeat(2), value: appeared)
                Spacer(minLength: 8)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(NightPalette.secondaryText)
                        .frame(width: 28, height: 28)
                        .background(NightPalette.chip, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Hide suggestions")
            }
            Text(batch.source == .gemini ? "AI picked these from your recent dreams. Tap to add one to your notes, or ⊕ to save it to your library."
                                         : "Picked from your recent dreams. Tap to add one to your notes, or ⊕ to save it to your library.")
                .font(.caption)
                .foregroundStyle(NightPalette.secondaryText)

            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(Array(batch.suggestions.enumerated()), id: \.element.id) { index, suggestion in
                    suggestionChip(suggestion)
                        .scaleEffect(appeared ? 1 : 0.4)
                        .opacity(appeared ? 1 : 0)
                        .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.6).delay(Double(index) * 0.06),
                                   value: appeared)
                }
            }
        }
        .padding(16)
        .background(NightPalette.cardGradient, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(LinearGradient(colors: [NightPalette.accent.opacity(0.8), DayPalette.accent.opacity(0.5)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2)
        }
        .shadow(color: NightPalette.glow.opacity(0.5), radius: 16, y: 6)
        .onAppear { appeared = true }
        .sensoryFeedback(.impact(weight: .light), trigger: appeared)
        .sensoryFeedback(.success, trigger: saved)
    }

    private func suggestionChip(_ suggestion: KeywordSuggestion) -> some View {
        let existing = store.keyword(matching: suggestion.name)
        let used = isUsed(suggestion.name)
        return HStack(spacing: 2) {
            Button { onPick(suggestion) } label: {
                KeywordChip(name: suggestion.name, kind: existing?.kind ?? suggestion.kind, isOn: used)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(suggestion.kind.shortLabel): \(suggestion.name)")
            .accessibilityHint("Adds it to your notes. " + suggestion.reason)
            .accessibilityAddTraits(used ? .isSelected : [])

            if existing == nil {
                Button {
                    store.upsert(Keyword(name: suggestion.name, kind: suggestion.kind, subtitle: suggestion.reason))
                    saved += 1
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.body)
                        .foregroundStyle(suggestion.kind.color.opacity(0.85))
                        .frame(width: 30, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Save \(suggestion.name) to your library")
            }
        }
        .contextMenu { Text(suggestion.reason) }
    }
}
