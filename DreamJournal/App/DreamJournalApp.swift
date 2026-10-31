import SwiftUI

@main
struct DreamJournalApp: App {
    @State private var store = JournalStore()

    var body: some Scene {
        WindowGroup {
            TimelineScreen()
                .environment(store)
                .preferredColorScheme(.dark)
                .environment(\.locale, Date.appLocale)
        }
    }
}

/// 导航目标
enum Route: Hashable {
    case day(UUID)
    case dream(UUID)
    case report(UUID)
    case keyword(UUID)
}

extension View {
    /// 主页和关键词库各有一个导航栈，共用同一套目标页面
    func routeDestinations(path: Binding<[Route]>) -> some View {
        navigationDestination(for: Route.self) { route in
            switch route {
            case .day(let id): DayDetailView(entryID: id)
            case .dream(let id): DreamDetailView(dreamID: id, path: path)
            case .report(let id): AnalysisReportView(dreamID: id, path: path)
            case .keyword(let id): KeywordProfileView(keywordID: id)
            }
        }
    }
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
    /// 启动后直接打开的页面：keywords（关键词库）/ capture（快速记梦）
    static var openSheet: String? { defaults.string(forKey: "openSheet") }
}
