import Foundation

/// 梦境分析服务。Mock 在本地模拟“检索 + LLM”，Remote 调用团队后端（后端再调用 Gemini）。
protocol AnalysisService {
    /// 把本地日记同步到后端，后端检索相关内容时要用到这些数据。
    func sync(days: [DayEntry], dreams: [DreamEntry]) async throws
    /// 分析一个梦：后端会检索时间上 / 内容上相关的白天日记和过往梦境，交给 LLM 生成报告。
    func analyze(dream: DreamEntry, store: JournalStore) async throws -> DreamAnalysis
    /// 从最近几天的梦里提炼关键词，供下次速记时一键填写。
    func suggestKeywords(recentDreams: [DreamEntry], existing: [Keyword]) async throws -> [KeywordSuggestion]
}

enum ServiceMode: String, CaseIterable, Identifiable {
    case mock, remote
    var id: String { rawValue }
    var label: String { self == .mock ? "Local mock (offline demo)" : "Backend (Gemini)" }
}

enum AppSettings {
    static let serviceModeKey = "serviceMode"
    static let backendURLKey = "backendURL"
    static let defaultBackendURL = "http://localhost:8000"

    static var serviceMode: ServiceMode {
        UserDefaults.standard.string(forKey: serviceModeKey).flatMap(ServiceMode.init(rawValue:)) ?? .mock
    }

    static var backendURL: String {
        UserDefaults.standard.string(forKey: backendURLKey) ?? defaultBackendURL
    }

    /// 匿名用户 ID，首次启动生成，用来在后端区分不同用户的日记。
    static var userID: String {
        if let id = UserDefaults.standard.string(forKey: "userID") { return id }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: "userID")
        return id
    }
}

enum AnalysisServiceFactory {
    static func current() -> AnalysisService {
        switch AppSettings.serviceMode {
        case .mock: MockAnalysisService()
        case .remote: RemoteAnalysisService(baseURL: AppSettings.backendURL)
        }
    }
}

enum AnalysisError: LocalizedError {
    case invalidURL(String)
    case server(code: String, message: String)
    case badStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url): "Invalid backend URL: \(url)"
        case .server(let code, let message): "Backend error (\(code)): \(message)"
        case .badStatus(let status): "Backend returned HTTP \(status)"
        }
    }
}
