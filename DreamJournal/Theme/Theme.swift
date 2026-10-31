import SwiftUI

/// 时间轴视图模式：日间 / 夜间 / 昼夜双卡
enum TimelineMode: String, CaseIterable, Identifiable {
    case day, night, dual
    var id: String { rawValue }

    var label: String {
        switch self {
        case .day: "日间"
        case .night: "夜间"
        case .dual: "昼夜"
        }
    }

    var icon: String {
        switch self {
        case .day: "sun.max.fill"
        case .night: "moon.stars.fill"
        case .dual: "circle.lefthalf.filled"
        }
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

/// 白天：深色“烛光”主题——暖棕底 + 琥珀橙点缀
enum DayPalette {
    static let background = Color(hex: 0x16110D)
    static let backgroundGradient = LinearGradient(colors: [Color(hex: 0x16110D), Color(hex: 0x21180F), Color(hex: 0x2B1D13)],
                                                   startPoint: .top, endPoint: .bottom)
    static let cardGradient = LinearGradient(colors: [Color(hex: 0x33261C, opacity: 0.92), Color(hex: 0x261C15, opacity: 0.92)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)
    static let accent = Color(hex: 0xFFAE6B)
    static let text = Color(hex: 0xF6E8DA)
    static let secondaryText = Color(hex: 0xBFA28B)
    static let chip = Color(hex: 0xFFAE6B, opacity: 0.16)
    /// 亮橙底上的深色文字
    static let ink = Color(hex: 0x2A190C)
}

/// 夜晚：暗紫 / 深空蓝
enum NightPalette {
    static let background = Color(hex: 0x0B1026)
    static let backgroundGradient = LinearGradient(colors: [Color(hex: 0x0B1026), Color(hex: 0x1B1640), Color(hex: 0x2A1B3D)],
                                                   startPoint: .top, endPoint: .bottom)
    static let cardGradient = LinearGradient(colors: [Color(hex: 0x2E2150, opacity: 0.85), Color(hex: 0x1A2350, opacity: 0.85)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)
    static let cardStroke = Color(hex: 0xB79CFF, opacity: 0.35)
    static let accent = Color(hex: 0xB79CFF)
    static let text = Color(hex: 0xE8E3FF)
    static let secondaryText = Color(hex: 0xA59CC8)
    static let chip = Color(hex: 0xB79CFF, opacity: 0.18)
    /// 深紫，用于亮色胶囊上的文字、阴影
    static let ink = Color(hex: 0x1B1640)
    static let glow = Color(hex: 0x5B3FA8)
    static let lavender = Color(hex: 0x8A6BE0)
    static let indigo = Color(hex: 0x3B4BC8)
    static let leaf = Color(hex: 0x8FE3B0)
    /// 备忘录式分组列表的底色与分隔线
    static let surface = Color(hex: 0x1F1A3D, opacity: 0.78)
    static let separator = Color(hex: 0xB79CFF, opacity: 0.16)
}

/// 昼夜双卡模式的背景：上暖下深的黄昏渐变
enum DuskPalette {
    static let backgroundGradient = LinearGradient(colors: [Color(hex: 0x2B1D13), Color(hex: 0x2A1B3D), Color(hex: 0x0B1026)],
                                                   startPoint: .top, endPoint: .bottom)
}

extension Date {
    var dayTitle: String { formatted(.dateTime.month().day().weekday(.abbreviated)) }
    var shortDay: String { formatted(.dateTime.month(.defaultDigits).day()) }
}

/// 标签胶囊
struct TagChip: View {
    let text: String
    let isNight: Bool

    var body: some View {
        Text("#\(text)")
            .font(.caption2.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(isNight ? NightPalette.chip : DayPalette.chip, in: Capsule())
            .foregroundStyle(isNight ? NightPalette.text : DayPalette.text)
            .accessibilityLabel("标签 \(text)")
    }
}

// MARK: - 卡片样式

enum CardTone { case day, night }

private struct JournalCardModifier: ViewModifier {
    let tone: CardTone
    var radius: CGFloat = 20
    var shadow = true

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background(tone == .day ? AnyShapeStyle(DayPalette.cardGradient) : AnyShapeStyle(NightPalette.cardGradient),
                        in: shape)
            .overlay {
                // 顶部高光描边，让卡片更有层次
                shape.strokeBorder(
                    LinearGradient(colors: tone == .day
                                   ? [DayPalette.accent.opacity(0.4), DayPalette.accent.opacity(0.08)]
                                   : [NightPalette.accent.opacity(0.55), NightPalette.cardStroke.opacity(0.15)],
                                   startPoint: .top, endPoint: .bottom),
                    lineWidth: 1)
            }
            .shadow(color: shadow ? (tone == .day ? Color.black.opacity(0.35) : NightPalette.glow.opacity(0.35)) : .clear,
                    radius: 12, y: 5)
    }
}

extension View {
    /// 统一的日 / 夜卡片外观（渐变底 + 高光描边 + 柔和投影）
    func journalCard(_ tone: CardTone, radius: CGFloat = 20, shadow: Bool = true) -> some View {
        modifier(JournalCardModifier(tone: tone, radius: radius, shadow: shadow))
    }
}

/// 可点击卡片的按压反馈：轻微缩放
struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .brightness(configuration.isPressed ? -0.02 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// 自动换行的流式布局，用于标签、主题等不定长胶囊
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, maxWidth: proposal.width ?? .infinity)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + CGFloat(max(rows.count - 1, 0)) * lineSpacing
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews, maxWidth: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                                      proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(_ subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = [Row()]
        for (i, view) in subviews.enumerated() {
            let size = view.sizeThatFits(.unspecified)
            let needed = rows[rows.count - 1].indices.isEmpty ? size.width : rows[rows.count - 1].width + spacing + size.width
            if needed > maxWidth, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            var row = rows[rows.count - 1]
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(i)
            rows[rows.count - 1] = row
        }
        return rows.filter { !$0.indices.isEmpty }
    }
}
