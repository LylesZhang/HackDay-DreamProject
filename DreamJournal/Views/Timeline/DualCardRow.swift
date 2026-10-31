import SwiftUI

/// 昼夜双卡：同一天左白天、右梦境；缺的一侧显示占位卡。
struct DualCardRow: View {
    let pair: DayNightPair
    var onAddDay: () -> Void
    var onAddDream: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(pair.date.dayTitle)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.black.opacity(0.18), in: Capsule())

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
            .buttonStyle(.plain)
            .frame(height: 170)
        }
    }
}

struct PlaceholderCard: View {
    let isNight: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: isNight ? "moon.zzz" : "sun.haze")
                .font(.title2)
            Text(isNight ? "+ 记录今晚的梦" : "+ 记录这一天")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(isNight ? NightPalette.accent : DayPalette.accent)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isNight ? Color(hex: 0x1A1640, opacity: 0.55) : Color.white.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                .foregroundStyle(isNight ? NightPalette.cardStroke : DayPalette.accent.opacity(0.5))
        )
    }
}
