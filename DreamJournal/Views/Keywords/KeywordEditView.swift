import SwiftUI

/// 新建 / 编辑关键词档案
struct KeywordEditView: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Keyword
    @State private var aliasText: String
    private let isEditing: Bool

    init(newKind: Keyword.Kind = .imagery, name: String = "") {
        _draft = State(initialValue: Keyword(name: name, kind: newKind))
        _aliasText = State(initialValue: "")
        isEditing = false
    }

    init(existing: Keyword) {
        _draft = State(initialValue: existing)
        _aliasText = State(initialValue: existing.aliases.joined(separator: " "))
        isEditing = true
    }

    private var trimmedName: String { draft.name.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// 名字已被别的关键词（名字或别名）占用
    private var conflict: Keyword? {
        guard let other = store.keyword(matching: trimmedName), other.id != draft.id else { return nil }
        return other
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NightPalette.backgroundGradient.ignoresSafeArea()
                Form {
                    Section {
                        Picker("Type", selection: $draft.kind) {
                            ForEach(Keyword.Kind.allCases) { Text($0.shortLabel).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }

                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: draft.kind.icon)
                                .font(.headline)
                                .foregroundStyle(draft.kind.color)
                                .frame(width: 36, height: 36)
                                .background(draft.kind.color.opacity(0.16), in: Circle())
                                .contentTransition(.symbolEffect(.replace))
                            TextField(draft.kind.namePlaceholder, text: $draft.name)
                                .font(.title3.weight(.semibold))
                        }
                        TextField(draft.kind.subtitlePlaceholder, text: $draft.subtitle, axis: .vertical)
                    } footer: {
                        if let conflict {
                            Text("“\(trimmedName)” is already the name or an alias of “\(conflict.name)”.")
                                .foregroundStyle(.orange)
                        }
                    }
                    .listRowBackground(FormRowBackground.night)

                    Section {
                        TextField("Space-separated, e.g. Nana Granny", text: $aliasText)
                    } header: {
                        Text("Aliases")
                    } footer: {
                        Text("Any dream that mentions the name or an alias links here automatically.")
                    }
                    .listRowBackground(FormRowBackground.night)

                    Section("Notes") {
                        TextEditor(text: $draft.note)
                            .frame(minHeight: 120)
                            .scrollContentBackground(.hidden)
                    }
                    .listRowBackground(FormRowBackground.night)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(isEditing ? "Edit Keyword" : "New Keyword")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(trimmedName.isEmpty || conflict != nil)
                }
            }
        }
        .tint(NightPalette.accent)
        .environment(\.colorScheme, .dark)
    }

    private func save() {
        draft.name = trimmedName
        draft.subtitle = draft.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        var seen = Set([draft.name.lowercased()])
        draft.aliases = TagParser.parse(aliasText).filter { seen.insert($0.lowercased()).inserted }
        store.upsert(draft)
        dismiss()
    }
}
