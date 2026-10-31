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
                            Label("That night's dream", systemImage: "moon.stars.fill")
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
                            Button("Edit", systemImage: "pencil") { editing = true }
                            Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete = true }
                        } label: { Label("More", systemImage: "ellipsis.circle") }
                    }
                }
                .sheet(isPresented: $editing) { DayComposeView(existing: entry) }
                .confirmationDialog("Delete this entry?", isPresented: $confirmDelete, titleVisibility: .visible) {
                    Button("Delete", role: .destructive) {
                        dismiss()
                        store.deleteDay(id: entryID)
                    }
                } message: { Text("This can't be undone.") }
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
