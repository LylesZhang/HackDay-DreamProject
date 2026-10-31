import SwiftUI

/// 新建 / 编辑白天日记
struct DayComposeView: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var draft: DayEntry
    @State private var tagText: String
    private let isEditing: Bool

    init(date: Date = .now, existing: DayEntry? = nil) {
        let entry = existing ?? DayEntry(date: date, title: "", content: "", mood: .calm)
        _draft = State(initialValue: entry)
        _tagText = State(initialValue: entry.tags.joined(separator: " "))
        isEditing = existing != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $draft.date, displayedComponents: .date)
                    TextField("Title, e.g. First interview", text: $draft.title)
                }
                .listRowBackground(FormRowBackground.day)
                Section("What happened today") {
                    TextEditor(text: $draft.content)
                        .frame(minHeight: 140)
                }
                .listRowBackground(FormRowBackground.day)
                Section("Mood") {
                    HStack {
                        ForEach(Mood.allCases) { mood in
                            Button {
                                draft.mood = mood
                            } label: {
                                VStack(spacing: 4) {
                                    MoodIcon(mood: mood, size: 40)
                                    Text(mood.label).font(.caption2)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(draft.mood == mood ? DayPalette.chip : .clear,
                                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .scaleEffect(draft.mood == mood ? 1.06 : 1)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: draft.mood)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(mood.label)
                            .accessibilityAddTraits(draft.mood == mood ? .isSelected : [])
                        }
                    }
                }
                .listRowBackground(FormRowBackground.day)
                Section("Tags (space-separated)") {
                    TextField("interview friends rain", text: $tagText)
                }
                .listRowBackground(FormRowBackground.day)
            }
            .scrollContentBackground(.hidden)
            .background(DayPalette.backgroundGradient.ignoresSafeArea())
            .foregroundStyle(DayPalette.text)
            .navigationTitle(isEditing ? "Edit Entry" : "Day Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(draft.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .tint(DayPalette.accent)
        .environment(\.colorScheme, .dark)
        .sensoryFeedback(.selection, trigger: draft.mood)
    }

    private func save() {
        draft.tags = TagParser.parse(tagText)
        if draft.title.trimmingCharacters(in: .whitespaces).isEmpty {
            draft.title = TagParser.autoTitle(from: draft.content)
        }
        store.upsert(draft)
        dismiss()
    }
}

enum TagParser {
    static func parse(_ text: String) -> [String] {
        text.components(separatedBy: CharacterSet(charactersIn: " ,，、#\n"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// 没写标题时从正文生成：取第一句，过长就在单词边界截断
    static func autoTitle(from content: String, maxLength: Int = 32) -> String {
        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstSentence = text.split(whereSeparator: { ".!?\n".contains($0) }).first.map(String.init) ?? text
        guard firstSentence.count > maxLength else { return firstSentence }
        let cut = firstSentence.prefix(maxLength)
        if let space = cut.lastIndex(of: " ") { return String(cut[..<space]) + "…" }
        return String(cut) + "…"
    }
}
