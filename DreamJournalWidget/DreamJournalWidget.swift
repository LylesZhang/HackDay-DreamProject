import SwiftUI
import WidgetKit

struct DreamJournalWidget: Widget {
    let kind = "DreamJournalWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DreamWidgetProvider()) { entry in
            DreamWidgetView(entry: entry)
        }
        .configurationDisplayName("快速记梦")
        .description("醒来时，立刻留住梦的片段。")
        // 锁屏：圆形 / 长条；主屏幕：小号 / 中号
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .systemSmall, .systemMedium])
    }
}

private struct DreamWidgetEntry: TimelineEntry {
    let date: Date

    /// 早上 5–11 点是“刚醒来”的时段，文案更偏向记录昨晚的梦
    var isMorning: Bool { (5..<11).contains(Calendar.current.component(.hour, from: date)) }
}

private struct DreamWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> DreamWidgetEntry { DreamWidgetEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (DreamWidgetEntry) -> Void) {
        completion(DreamWidgetEntry(date: .now))
    }
    /// 在早上 5 点和 11 点切换文案，所以给出接下来这两个时间点的条目
    func getTimeline(in context: Context, completion: @escaping (Timeline<DreamWidgetEntry>) -> Void) {
        let cal = Calendar.current
        let now = Date.now
        let boundaries = [5, 11].compactMap {
            cal.nextDate(after: now, matching: DateComponents(hour: $0, minute: 0), matchingPolicy: .nextTime)
        }.sorted()
        let entries = [DreamWidgetEntry(date: now)] + boundaries.map { DreamWidgetEntry(date: $0) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// 小组件是独立 target，用不到 App 里的 Theme，这里放一份最小的夜间色板
private enum WidgetPalette {
    static let background = LinearGradient(
        colors: [Color(red: 0.043, green: 0.063, blue: 0.149),   // #0B1026
                 Color(red: 0.106, green: 0.086, blue: 0.251),   // #1B1640
                 Color(red: 0.165, green: 0.106, blue: 0.239)],  // #2A1B3D
        startPoint: .topLeading, endPoint: .bottomTrailing)
    static let accent = Color(red: 0.718, green: 0.612, blue: 1.0)        // #B79CFF
    static let text = Color(red: 0.910, green: 0.890, blue: 1.0)          // #E8E3FF
    static let secondaryText = Color(red: 0.647, green: 0.612, blue: 0.784) // #A59CC8
    static let warm = Color(red: 1.0, green: 0.624, blue: 0.353)          // #FF9F5A
}

private struct DreamWidgetView: View {
    let entry: DreamWidgetEntry
    private let quickCaptureURL = URL(string: "dreamjournal://quick-capture")!
    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .widgetURL(quickCaptureURL)
            .containerBackground(for: .widget) { background }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryRectangular:
            HStack(spacing: 10) {
                Image(systemName: "mic.fill")
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("快速记梦")
                        .font(.headline)
                    Text("留住刚醒来的片段")
                        .font(.caption2)
                }
            }
        case .accessoryCircular:
            Image(systemName: "moon.stars.fill")
                .font(.title2)
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    @ViewBuilder
    private var background: some View {
        switch family {
        case .accessoryCircular:
            AccessoryWidgetBackground()
        case .accessoryRectangular:
            Color.clear
        default:
            ZStack {
                WidgetPalette.background
                StaticStars()
            }
        }
    }

    // MARK: - 主屏幕

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "moon.stars.fill")
                .font(.title2)
                .foregroundStyle(WidgetPalette.accent)
            Spacer(minLength: 0)
            Text("快速记梦")
                .font(.headline)
                .foregroundStyle(WidgetPalette.text)
            Text(entry.isMorning ? "趁梦还记得" : "随时留住梦的片段")
                .font(.caption2)
                .foregroundStyle(WidgetPalette.secondaryText)
            micPill
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var mediumView: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Label(entry.isMorning ? "早安" : "昼夜日记", systemImage: entry.isMorning ? "sunrise.fill" : "moon.stars.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(entry.isMorning ? WidgetPalette.warm : WidgetPalette.accent)
                Spacer(minLength: 0)
                Text(entry.isMorning ? "昨晚梦见了什么？" : "刚刚梦见了什么？")
                    .font(.headline)
                    .foregroundStyle(WidgetPalette.text)
                Text("说一句、点几个关键词就好，细节晚些再整理。")
                    .font(.caption2)
                    .foregroundStyle(WidgetPalette.secondaryText)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            VStack(spacing: 6) {
                Image(systemName: "mic.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color(red: 0.106, green: 0.086, blue: 0.251))
                    .frame(width: 56, height: 56)
                    .background(WidgetPalette.accent, in: Circle())
                    .shadow(color: WidgetPalette.accent.opacity(0.6), radius: 8)
                Text("说一说")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(WidgetPalette.text)
            }
        }
    }

    private var micPill: some View {
        Label("说一说", systemImage: "mic.fill")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color(red: 0.106, green: 0.086, blue: 0.251))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(WidgetPalette.accent, in: Capsule())
    }
}

/// 固定位置的小星星（小组件不支持动画，用静态点缀）
private struct StaticStars: View {
    private static let stars: [(x: Double, y: Double, size: Double, alpha: Double)] = [
        (0.12, 0.18, 2.0, 0.8), (0.78, 0.12, 1.5, 0.6), (0.55, 0.30, 1.2, 0.5), (0.90, 0.45, 2.2, 0.7),
        (0.30, 0.55, 1.4, 0.4), (0.68, 0.70, 1.8, 0.6), (0.18, 0.82, 1.2, 0.5), (0.85, 0.88, 1.6, 0.5),
        (0.45, 0.10, 1.0, 0.4), (0.62, 0.50, 1.0, 0.35),
    ]

    var body: some View {
        Canvas { ctx, size in
            for s in Self.stars {
                let rect = CGRect(x: s.x * size.width, y: s.y * size.height, width: s.size, height: s.size)
                ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(s.alpha)))
            }
        }
    }
}

#Preview(as: .systemSmall) {
    DreamJournalWidget()
} timeline: {
    DreamWidgetEntry(date: .now)
}

#Preview(as: .systemMedium) {
    DreamJournalWidget()
} timeline: {
    DreamWidgetEntry(date: .now)
}

// 锁屏版：模拟器里不方便编辑锁屏时，用画布预览看效果
#Preview(as: .accessoryRectangular) {
    DreamJournalWidget()
} timeline: {
    DreamWidgetEntry(date: .now)
}

#Preview(as: .accessoryCircular) {
    DreamJournalWidget()
} timeline: {
    DreamWidgetEntry(date: .now)
}

@main
struct DreamJournalWidgetBundle: WidgetBundle {
    var body: some Widget {
        DreamJournalWidget()
    }
}
