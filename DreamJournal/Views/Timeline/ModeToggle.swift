import SwiftUI

/// 日间 / 夜间 / 昼夜 三段胶囊开关
struct ModeToggle: View {
    @Binding var mode: TimelineMode
    @Namespace private var ns

    private var isNight: Bool { mode == .night }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(TimelineMode.allCases) { m in
                Button {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { mode = m }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: m.icon)
                            .symbolEffect(.bounce, value: mode == m)
                        Text(m.label)
                            .lineLimit(1)
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .foregroundStyle(foreground(for: m))
                    .background {
                        if mode == m {
                            Capsule()
                                .fill(selectionFill(for: m))
                                .matchedGeometryEffect(id: "selection", in: ns)
                                .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(mode == m ? .isSelected : [])
            }
        }
        .padding(4)
        .background(.ultraThinMaterial, in: Capsule())
        .environment(\.colorScheme, .dark)
        .sensoryFeedback(.selection, trigger: mode)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("时间轴模式")
    }

    private func foreground(for m: TimelineMode) -> Color {
        if mode == m { return m == .day ? DayPalette.ink : .white }
        return isNight ? NightPalette.secondaryText : DayPalette.secondaryText
    }

    private func selectionFill(for m: TimelineMode) -> AnyShapeStyle {
        switch m {
        case .day:
            AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xFFE2B8), DayPalette.accent], startPoint: .topLeading, endPoint: .bottomTrailing))
        case .night:
            AnyShapeStyle(LinearGradient(colors: [NightPalette.glow, Color(hex: 0x1F2A6B)], startPoint: .topLeading, endPoint: .bottomTrailing))
        case .dual:
            AnyShapeStyle(LinearGradient(colors: [DayPalette.accent, NightPalette.glow], startPoint: .leading, endPoint: .trailing))
        }
    }
}
