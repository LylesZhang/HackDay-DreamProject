import SwiftUI

/// 梦境卡片：暗紫 / 深空蓝
struct DreamCardView: View {
    let entry: DreamEntry
    var compact = false

    private static let moonPhases = [
        "moonphase.waxing.crescent", "moonphase.first.quarter", "moonphase.waxing.gibbous", "moonphase.full.moon",
        "moonphase.waning.gibbous", "moonphase.last.quarter", "moonphase.waning.crescent", "moonphase.new.moon",
    ]

    private var moonIcon: String {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: entry.dreamDate) ?? 0
        return Self.moonPhases[dayOfYear % Self.moonPhases.count]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 10) {
            HStack(alignment: .firstTextBaseline) {
                Label(compact ? entry.dreamDate.shortDay : entry.dreamDate.dayTitle + " · 夜", systemImage: moonIcon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NightPalette.accent)
                Spacer(minLength: 4)
                if entry.analysis != nil {
                    Text(compact ? "✨" : "✨ 已分析")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, compact ? 0 : 8)
                        .padding(.vertical, 3)
                        .background(compact ? Color.clear : NightPalette.chip, in: Capsule())
                        .foregroundStyle(NightPalette.text)
                }
            }
            Text(entry.title)
                .font(compact ? .subheadline.weight(.bold) : .headline)
                .foregroundStyle(NightPalette.text)
                .lineLimit(compact ? 2 : 1)
            Text(entry.content)
                .font(compact ? .caption : .subheadline)
                .foregroundStyle(NightPalette.secondaryText)
                .lineLimit(compact ? 3 : 2)
            if !compact {
                HStack(spacing: 6) {
                    ForEach(entry.emotions.prefix(3), id: \.self) { TagChip(text: $0, isNight: true) }
                    if entry.isLucid { TagChip(text: "清醒梦", isNight: true) }
                    Spacer()
                    VividnessStars(value: entry.vividness)
                }
            } else {
                Spacer(minLength: 0)
                VividnessStars(value: entry.vividness)
            }
        }
        .padding(compact ? 12 : 16)
        .frame(maxWidth: .infinity, maxHeight: compact ? .infinity : nil, alignment: .topLeading)
        .background(NightPalette.cardGradient, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(NightPalette.cardStroke))
        .shadow(color: Color(hex: 0x5B3FA8).opacity(0.35), radius: 12, y: 4)
    }
}

/// 梦境清晰度（1–5 颗星）
struct VividnessStars: View {
    let value: Int

    var body: some View {
        HStack(spacing: 1) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: i <= value ? "star.fill" : "star")
            }
        }
        .font(.system(size: 9))
        .foregroundStyle(NightPalette.accent)
    }
}
