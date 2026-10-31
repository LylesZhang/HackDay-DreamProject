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
                    DatePicker("日期", selection: $draft.date, displayedComponents: .date)
                    TextField("一句话标题，比如：第一次面试", text: $draft.title)
                }
                .listRowBackground(FormRowBackground.day)
                Section("今天发生了什么") {
                    TextEditor(text: $draft.content)
                        .frame(minHeight: 140)
                }
                .listRowBackground(FormRowBackground.day)
                Section("心情") {
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
                Section("标签（空格分隔）") {
                    TextField("面试 朋友 下雨", text: $tagText)
                }
                .listRowBackground(FormRowBackground.day)
            }
            .scrollContentBackground(.hidden)
            .background(DayPalette.backgroundGradient.ignoresSafeArea())
            .foregroundStyle(DayPalette.text)
            .navigationTitle(isEditing ? "编辑日记" : "白天日记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
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
            draft.title = String(draft.content.prefix(12))
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
}
