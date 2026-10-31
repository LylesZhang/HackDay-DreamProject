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
                if entry.analysis != nil { analyzedBadge }
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
                    Spacer(minLength: 0)
                    VividnessStars(value: entry.vividness)
                }
            } else {
                Spacer(minLength: 0)
                VividnessStars(value: entry.vividness)
            }
        }
        .padding(compact ? 12 : 16)
        .frame(maxWidth: .infinity, maxHeight: compact ? .infinity : nil, alignment: .topLeading)
        .journalCard(.night)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityHint("查看梦境详情")
    }

    @ViewBuilder
    private var analyzedBadge: some View {
        if compact {
            Image(systemName: "sparkles")
                .font(.caption)
                .foregroundStyle(NightPalette.accent)
                .accessibilityLabel("已分析")
        } else {
            Label("已分析", systemImage: "sparkles")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(NightPalette.chip, in: Capsule())
                .foregroundStyle(NightPalette.text)
        }
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
        .font(.caption2)
        .imageScale(.small)
        .foregroundStyle(NightPalette.accent)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("清晰度 \(value) 星，共 5 星")
    }
}
