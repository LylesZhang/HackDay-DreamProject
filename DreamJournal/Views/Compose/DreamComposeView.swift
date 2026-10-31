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
                    Section("梦里发生了什么") {
                        TextEditor(text: $draft.content)
                            .frame(minHeight: 160)
                            .scrollContentBackground(.hidden)
                    }
                    Section("梦里的情绪") {
                        FlowChips(options: DreamEntry.emotionOptions, selection: $draft.emotions)
                    }
                    Section {
                        HStack {
                            Text("清晰度")
                            Spacer()
                            ForEach(1...5, id: \.self) { i in
                                Button { draft.vividness = i } label: {
                                    Image(systemName: i <= draft.vividness ? "star.fill" : "star")
                                        .foregroundStyle(NightPalette.accent)
                                        .symbolEffect(.bounce, value: draft.vividness == i)
                                        .frame(width: 30, height: 36)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("清晰度")
                        .accessibilityValue("\(draft.vividness) 星，共 5 星")
                        .accessibilityAdjustableAction { direction in
                            switch direction {
                            case .increment: draft.vividness = min(5, draft.vividness + 1)
                            case .decrement: draft.vividness = max(1, draft.vividness - 1)
                            @unknown default: break
                            }
                        }
                        Toggle("这是一个清醒梦", isOn: $draft.isLucid)
                    }
                    Section("标签（空格分隔）") {
                        TextField("水 飞 迷路", text: $tagText)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(isEditing ? "编辑梦境" : "🌙 梦境日记")
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
        .sensoryFeedback(.selection, trigger: draft.vividness)
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
