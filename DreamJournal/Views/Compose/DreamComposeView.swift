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
                        DatePicker("做梦的那一晚", selection: $draft.dreamDate, displayedComponents: .date)
                        TextField("给这个梦起个名字", text: $draft.title)
                    }
                    .listRowBackground(FormRowBackground.night)
                    Section("梦里发生了什么") {
                        TextEditor(text: $draft.content)
                            .frame(minHeight: 160)
                            .scrollContentBackground(.hidden)
                    }
                    .listRowBackground(FormRowBackground.night)
                    Section("梦里的情绪") {
                        FlowChips(options: DreamEntry.emotionOptions, selection: $draft.emotions)
                    }
                    .listRowBackground(FormRowBackground.night)
                    Section {
                        HStack {
                            Text("清晰度")
                            Spacer()
                            ForEach(1...5, id: \.self) { i in
                                Image(systemName: i <= draft.vividness ? "star.fill" : "star")
                                    .foregroundStyle(NightPalette.accent)
                                    .onTapGesture { draft.vividness = i }
                            }
                        }
                        Toggle("这是一个清醒梦", isOn: $draft.isLucid)
                    }
                    .listRowBackground(FormRowBackground.night)
                    Section("标签（空格分隔）") {
                        TextField("水 飞 迷路", text: $tagText)
                    }
                    .listRowBackground(FormRowBackground.night)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(isEditing ? "编辑梦境" : "梦境日记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .disabled(draft.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .tint(NightPalette.accent)
        .environment(\.colorScheme, .dark)
    }

    private func save() {
        draft.tags = TagParser.parse(tagText)
        if draft.title.trimmingCharacters(in: .whitespaces).isEmpty {
            draft.title = String(draft.content.prefix(12))
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
                Text(option)
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(on ? NightPalette.accent.opacity(0.85) : NightPalette.chip, in: Capsule())
                    .foregroundStyle(on ? Color(hex: 0x1B1640) : NightPalette.text)
                    .onTapGesture {
                        if on { selection.removeAll { $0 == option } } else { selection.append(option) }
                    }
            }
        }
        .padding(.vertical, 4)
    }
}
