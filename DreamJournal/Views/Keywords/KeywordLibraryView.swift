import SwiftUI

/// 关键词库：查看、搜索、新建、删除关键词，并收下 AI 的建议
struct KeywordLibraryView: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var path: [Route] = []
    @State private var search = ""
    @State private var creating: Keyword.Kind?

    private func items(_ kind: Keyword.Kind) -> [Keyword] {
        let all = store.keywords(of: kind)
        let q = search.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return all }
        return all.filter { $0.isMentioned(in: q) || $0.terms.contains { $0.localizedCaseInsensitiveContains(q) }
            || $0.subtitle.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                NightPalette.backgroundGradient.ignoresSafeArea()
                List {
                    if search.isEmpty, !store.newKeywordSuggestions.isEmpty { suggestionSection }

                    ForEach(Keyword.Kind.allCases) { kind in
                        let list = items(kind)
                        if !list.isEmpty || search.isEmpty {
                            Section {
                                ForEach(list) { keyword in
                                    NavigationLink(value: Route.keyword(keyword.id)) {
                                        KeywordRow(keyword: keyword, count: store.dreams(mentioning: keyword).count)
                                    }
                                    .swipeActions {
                                        Button(role: .destructive) { store.deleteKeyword(id: keyword.id) } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                                if list.isEmpty {
                                    Button { creating = kind } label: {
                                        Label("Add your first \(kind.shortLabel.lowercased())", systemImage: "plus")
                                            .foregroundStyle(NightPalette.secondaryText)
                                    }
                                }
                            } header: {
                                Label(kind.label, systemImage: kind.icon).foregroundStyle(kind.color)
                            }
                            .listRowBackground(NightPalette.surface)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .overlay {
                    if !search.isEmpty, Keyword.Kind.allCases.allSatisfy({ items($0).isEmpty }) {
                        ContentUnavailableView.search(text: search)
                    }
                }
            }
            .searchable(text: $search, prompt: "Search keywords or aliases")
            .navigationTitle("Keywords")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        ForEach(Keyword.Kind.allCases) { kind in
                            Button("New \(kind.shortLabel)", systemImage: kind.icon) { creating = kind }
                        }
                    } label: { Label("New keyword", systemImage: "plus") }
                }
            }
            .routeDestinations(path: $path)
            .sheet(item: $creating) { KeywordEditView(newKind: $0) }
        }
        .tint(NightPalette.accent)
        .environment(\.colorScheme, .dark)
    }

    private var suggestionSection: some View {
        Section {
            ForEach(store.newKeywordSuggestions) { suggestion in
                HStack(spacing: 12) {
                    KeywordIcon(kind: suggestion.kind)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.name).font(.headline).foregroundStyle(NightPalette.text)
                        Text(suggestion.reason).font(.caption).foregroundStyle(NightPalette.secondaryText).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Button("Save") {
                        store.upsert(Keyword(name: suggestion.name, kind: suggestion.kind, subtitle: suggestion.reason))
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                    .accessibilityLabel("Save \(suggestion.name) to your library")
                }
            }
        } header: {
            Label("Found in the last \(KeywordExtractor.lookbackDays) days", systemImage: "sparkles")
                .foregroundStyle(NightPalette.accent)
        }
        .listRowBackground(NightPalette.surface)
    }
}

struct KeywordIcon: View {
    let kind: Keyword.Kind
    var size: CGFloat = 34

    var body: some View {
        Image(systemName: kind.icon)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(kind.color)
            .frame(width: size, height: size)
            .background(kind.color.opacity(0.16), in: Circle())
            .accessibilityHidden(true)
    }
}

private struct KeywordRow: View {
    let keyword: Keyword
    let count: Int

    var body: some View {
        HStack(spacing: 12) {
            KeywordIcon(kind: keyword.kind)
            VStack(alignment: .leading, spacing: 2) {
                Text(keyword.name).font(.headline).foregroundStyle(NightPalette.text)
                if !keyword.subtitle.isEmpty {
                    Text(keyword.subtitle).font(.caption).foregroundStyle(NightPalette.secondaryText).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Text(count == 0 ? "Not yet" : "\(count) \(count == 1 ? "dream" : "dreams")")
                .font(.caption.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(NightPalette.secondaryText)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
