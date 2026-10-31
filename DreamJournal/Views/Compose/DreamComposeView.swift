import SwiftUI

/// 新建 / 编辑梦境日记
struct DreamComposeView: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var draft: DreamEntry
    @State private var tagText: String
    private let isEditing: Bool

    init(date: Date = .now, existing: DreamEntry? = nil) {
        let entry = existing ?? DreamEntry(dreamDate: date, recordedAt: .now, title: "", content: "")
        _draft = State(initialValue: entry)
        _tagText = State(initialValue: entry.tags.joined(separator: " "))
        isEditing = existing != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NightPalette.backgroundGradient.ignoresSafeArea()
                StarfieldView(starCount: 60).ignoresSafeArea()
                Form {
                    Section {
                        DatePicker("Night of", selection: $draft.dreamDate, displayedComponents: .date)
                        TextField("Give this dream a name", text: $draft.title)
                    }
                    .listRowBackground(FormRowBackground.night)
                    Section("What happened in the dream") {
                        TextEditor(text: $draft.content)
                            .frame(minHeight: 160)
                            .scrollContentBackground(.hidden)
                    }
                    .listRowBackground(FormRowBackground.night)
                    Section {
                        KeywordPicker(isUsed: { $0.isMentioned(in: draft.content) },
                                      onPick: { keyword in
                                          withAnimation(.snappy) { KeywordLinker.append(keyword.name, to: &draft.content) }
                                      })
                    } header: {
                        Text("Tap a keyword to add it")
                    }
                    .listRowBackground(FormRowBackground.night)
                    Section("Feelings in the dream") {
                        FlowChips(options: DreamEntry.emotionOptions, selection: $draft.emotions)
                    }
                    .listRowBackground(FormRowBackground.night)
                    Section {
                        Toggle("This was a lucid dream", isOn: $draft.isLucid)
                    }
                    .listRowBackground(FormRowBackground.night)
                    Section("Tags (space-separated)") {
                        TextField("water flying lost", text: $tagText)
                    }
                    .listRowBackground(FormRowBackground.night)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(isEditing ? "Edit Dream" : "Dream Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(draft.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .tint(NightPalette.accent)
        .environment(\.colorScheme, .dark)
    }

    private func save() {
        draft.tags = TagParser.parse(tagText)
        // 提到的关键词同时记为标签，梦境列表里可以按它筛选
        for name in store.keywords(in: draft).map(\.name) where !draft.tags.contains(name) { draft.tags.append(name) }
        if draft.title.trimmingCharacters(in: .whitespaces).isEmpty {
            draft.title = TagParser.autoTitle(from: draft.content)
        }
        if !isEditing { draft.recordedAt = .now }
        store.upsert(draft)
        dismiss()
    }
}

/// 可多选的情绪胶囊
struct FlowChips: View {
    let options: [String]
    @Binding var selection: [String]

    private let columns = [GridItem(.adaptive(minimum: 64), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(options, id: \.self) { option in
                let on = selection.contains(option)
                Button {
                    if on { selection.removeAll { $0 == option } } else { selection.append(option) }
                } label: {
                    Text(option)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .background(on ? NightPalette.accent.opacity(0.85) : NightPalette.chip, in: Capsule())
                        .overlay(Capsule().strokeBorder(NightPalette.accent.opacity(on ? 0 : 0.3), lineWidth: 1))
                        .foregroundStyle(on ? NightPalette.ink : NightPalette.text)
                        .contentShape(Capsule())
                }
                .buttonStyle(.borderless)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
        .animation(.snappy(duration: 0.2), value: selection)
        .sensoryFeedback(.selection, trigger: selection)
    }
}
