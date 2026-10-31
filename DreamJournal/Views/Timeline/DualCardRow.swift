import SwiftUI

/// 昼夜双卡：同一天左白天、右梦境；缺的一侧显示占位卡。
struct DualCardRow: View {
    let pair: DayNightPair
    var onAddDay: () -> Void
    var onAddDream: () -> Void
    @ScaledMetric(relativeTo: .body) private var cardHeight: CGFloat = 170

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(pair.date.dayTitle)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.black.opacity(0.18), in: Capsule())
                .accessibilityAddTraits(.isHeader)

            HStack(alignment: .top, spacing: 10) {
                Group {
                    if let day = pair.day {
                        NavigationLink(value: Route.day(day.id)) { DayCardView(entry: day, compact: true) }
                    } else {
                        Button(action: onAddDay) { PlaceholderCard(isNight: false) }
                    }
                }
                Group {
                    if let dream = pair.dream {
                        NavigationLink(value: Route.dream(dream.id)) { DreamCardView(entry: dream, compact: true) }
                    } else {
                        Button(action: onAddDream) { PlaceholderCard(isNight: true) }
                    }
                }
            }
            .buttonStyle(PressableCardStyle())
            // 高度随动态字体等比放大，大字号下内容不被截断
            .frame(height: cardHeight)
        }
    }
}

struct PlaceholderCard: View {
    let isNight: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: isNight ? "moon.zzz" : "sun.haze")
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
            Text(isNight ? "记录今晚的梦" : "记录这一天")
                .font(.caption.weight(.semibold))
            Image(systemName: "plus.circle.fill")
                .font(.callout)
        }
        .foregroundStyle(isNight ? NightPalette.accent : DayPalette.accent)
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isNight ? NightPalette.ink.opacity(0.55) : Color(hex: 0x261C15, opacity: 0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                .foregroundStyle(isNight ? NightPalette.cardStroke : DayPalette.accent.opacity(0.5))
        )
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isNight ? "记录这一晚的梦" : "记录这一天")
    }
}
