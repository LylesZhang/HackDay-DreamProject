import SwiftUI

/// 白天日记详情
struct DayDetailView: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let entryID: UUID
    @State private var editing = false
    @State private var confirmDelete = false

    var body: some View {
        ZStack {
            DayPalette.backgroundGradient.ignoresSafeArea()
            if let entry = store.day(id: entryID) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Label(entry.date.dayTitle, systemImage: "sun.max.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(DayPalette.accent)
                            Spacer()
                            HStack(spacing: 6) {
                                MoodIcon(mood: entry.mood, size: 26)
                                Text(entry.mood.label)
                            }
                            .font(.subheadline)
                            .foregroundStyle(DayPalette.secondaryText)
                        }
                        Text(entry.title)
                            .font(.title.weight(.bold))
                            .foregroundStyle(DayPalette.text)
                        Text(entry.content)
                            .font(.body)
                            .lineSpacing(6)
                            .foregroundStyle(DayPalette.text)
                        if !entry.tags.isEmpty {
                            FlowLayout { ForEach(entry.tags, id: \.self) { TagChip(text: $0, isNight: false) } }
                        }
                        if let dream = sameNightDream(for: entry) {
                            Label("当晚的梦", systemImage: "moon.stars.fill")
                                .font(.headline)
                                .foregroundStyle(DayPalette.text)
                                .padding(.top, 12)
                                .accessibilityAddTraits(.isHeader)
                            NavigationLink(value: Route.dream(dream.id)) { DreamCardView(entry: dream) }
                                .buttonStyle(PressableCardStyle())
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .journalCard(.day, radius: 24)
                    .padding(16)
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button("编辑", systemImage: "pencil") { editing = true }
                            Button("删除", systemImage: "trash", role: .destructive) { confirmDelete = true }
                        } label: { Label("更多", systemImage: "ellipsis.circle") }
                    }
                }
                .sheet(isPresented: $editing) { DayComposeView(existing: entry) }
                .confirmationDialog("删除这篇日记？", isPresented: $confirmDelete, titleVisibility: .visible) {
                    Button("删除", role: .destructive) {
                        dismiss()
                        store.deleteDay(id: entryID)
                    }
                } message: { Text("删除后无法恢复") }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .tint(DayPalette.accent)
    }

    private func sameNightDream(for entry: DayEntry) -> DreamEntry? {
        store.dreamEntries.first { Calendar.current.isDate($0.dreamDate, inSameDayAs: entry.date) }
    }
}
