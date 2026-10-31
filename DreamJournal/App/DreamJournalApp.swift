import SwiftUI

@main
struct DreamJournalApp: App {
    @State private var store = JournalStore()

    var body: some Scene {
        WindowGroup {
            TimelineScreen()
                .environment(store)
        }
    }
}

/// 导航目标
enum Route: Hashable {
    case day(UUID)
    case dream(UUID)
    case report(UUID)
}

/// 演示用启动参数（xcrun simctl launch booted com.hackday.DreamJournal -initialMode night ...）
enum DemoLaunch {
    private static let defaults = UserDefaults.standard
    /// day / night / dual
    static var initialMode: TimelineMode? { defaults.string(forKey: "initialMode").flatMap(TimelineMode.init(rawValue:)) }
    /// 启动后直接打开第 N 个梦（0 = 最新）
    static var openDreamIndex: Int? { defaults.string(forKey: "openDream").flatMap { Int($0) } }
    /// 打开梦后自动触发 AI 分析
    static var autoAnalyze: Bool { defaults.bool(forKey: "autoAnalyze") }
}
