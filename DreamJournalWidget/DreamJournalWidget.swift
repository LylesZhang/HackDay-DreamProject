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
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

private struct DreamWidgetEntry: TimelineEntry {
    let date: Date
}

private struct DreamWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> DreamWidgetEntry { DreamWidgetEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (DreamWidgetEntry) -> Void) {
        completion(DreamWidgetEntry(date: .now))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<DreamWidgetEntry>) -> Void) {
        completion(Timeline(entries: [DreamWidgetEntry(date: .now)], policy: .never))
    }
}

private struct DreamWidgetView: View {
    let entry: DreamWidgetEntry
    private let quickCaptureURL = URL(string: "dreamjournal://quick-capture")!
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Link(destination: quickCaptureURL) {
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
            default:
                Image(systemName: "moon.stars.fill")
                    .font(.title2)
            }
        }
        .widgetURL(quickCaptureURL)
    }
}

@main
struct DreamJournalWidgetBundle: WidgetBundle {
    var body: some Widget {
        DreamJournalWidget()
    }
}
