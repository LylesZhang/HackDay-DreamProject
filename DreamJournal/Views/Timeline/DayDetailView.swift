import SwiftUI

/// 白天日记详情
struct DayDetailView: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let entryID: UUID
    @State private var editing = false

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
                            HStack { ForEach(entry.tags, id: \.self) { TagChip(text: $0, isNight: false) } }
                        }
                        if let dream = sameNightDream(for: entry) {
                            Text("当晚的梦").font(.headline).foregroundStyle(DayPalette.text).padding(.top, 12)
                            NavigationLink(value: Route.dream(dream.id)) { DreamCardView(entry: dream) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DayPalette.cardGradient, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .padding(16)
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button("编辑", systemImage: "pencil") { editing = true }
                            Button("删除", systemImage: "trash", role: .destructive) {
                                dismiss()
                                store.deleteDay(id: entryID)
                            }
                        } label: { Image(systemName: "ellipsis.circle") }
                    }
                }
                .sheet(isPresented: $editing) { DayComposeView(existing: entry) }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.light, for: .navigationBar)
        .tint(DayPalette.accent)
    }

    private func sameNightDream(for entry: DayEntry) -> DreamEntry? {
        store.dreamEntries.first { Calendar.current.isDate($0.dreamDate, inSameDayAs: entry.date) }
    }
}
