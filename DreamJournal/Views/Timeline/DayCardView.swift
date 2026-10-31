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
                Spacer(minLength: 4)
                Text(entry.mood.emoji).font(compact ? .body : .title3)
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
        .background(DayPalette.cardGradient, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(DayPalette.accent.opacity(0.18)))
        .shadow(color: DayPalette.accent.opacity(0.18), radius: 10, y: 4)
    }
}
