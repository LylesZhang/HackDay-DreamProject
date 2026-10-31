import SwiftUI

/// 白天卡片：暖白 / 淡橙
struct DayCardView: View {
    let entry: DayEntry
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 10) {
            HStack(alignment: .firstTextBaseline) {
                Label(compact ? entry.date.shortDay : entry.date.dayTitle, systemImage: "sun.max.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DayPalette.accent)
                    .symbolRenderingMode(.hierarchical)
                Spacer(minLength: 4)
                MoodIcon(mood: entry.mood, size: compact ? 24 : 30)
            }
            Text(entry.title)
                .font(compact ? .subheadline.weight(.bold) : .headline)
                .foregroundStyle(DayPalette.text)
                .lineLimit(compact ? 2 : 1)
            Text(entry.content)
                .font(compact ? .caption : .subheadline)
                .foregroundStyle(DayPalette.secondaryText)
                .lineLimit(compact ? 3 : 2)
            if !compact, !entry.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(entry.tags.prefix(3), id: \.self) { TagChip(text: $0, isNight: false) }
                }
            }
            if compact { Spacer(minLength: 0) }
        }
        .padding(compact ? 12 : 16)
        .frame(maxWidth: .infinity, maxHeight: compact ? .infinity : nil, alignment: .topLeading)
        .journalCard(.day)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens this day entry")
    }
}
