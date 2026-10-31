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

/// 白天：暖白 / 淡橙
enum DayPalette {
    static let background = Color(hex: 0xFFF8F0)
    static let backgroundGradient = LinearGradient(colors: [Color(hex: 0xFFF8F0), Color(hex: 0xFFEBD6)],
                                                   startPoint: .top, endPoint: .bottom)
    static let cardGradient = LinearGradient(colors: [Color(hex: 0xFFFFFF), Color(hex: 0xFFE8D1)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)
    static let accent = Color(hex: 0xFF9F5A)
    static let text = Color(hex: 0x4A3426)
    static let secondaryText = Color(hex: 0x8A6A55)
    static let chip = Color(hex: 0xFFD8A8, opacity: 0.6)
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
}

/// 昼夜双卡模式的背景：上暖下深的黄昏渐变
enum DuskPalette {
    static let backgroundGradient = LinearGradient(colors: [Color(hex: 0xFFE3C4), Color(hex: 0xC9A3D9), Color(hex: 0x2A1B3D)],
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
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(isNight ? NightPalette.chip : DayPalette.chip, in: Capsule())
            .foregroundStyle(isNight ? NightPalette.text : DayPalette.text)
    }
}
