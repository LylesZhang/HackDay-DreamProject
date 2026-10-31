import Foundation

/// 调用团队后端：POST /api/v1/entries/sync，然后 POST /api/v1/dreams/analyze。
struct RemoteAnalysisService: AnalysisService {
    var baseURL: String
    var session: URLSession = .shared

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        // 兼容带毫秒和不带毫秒的 ISO8601
        d.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            let withFraction = ISO8601DateFormatter()
            withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = withFraction.date(from: raw) ?? ISO8601DateFormatter().date(from: raw) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Bad date: \(raw)"))
        }
        return d
    }()

    func sync(days: [DayEntry], dreams: [DreamEntry]) async throws {
        let body = SyncRequest(userId: AppSettings.userID, days: days.map(DayEntryDTO.init), dreams: dreams.map(DreamEntryDTO.init))
        _ = try await post("/api/v1/entries/sync", body: body)
    }

    func analyze(dream: DreamEntry, store: JournalStore) async throws -> DreamAnalysis {
        try await sync(days: store.dayEntries, dreams: store.dreamEntries)
        let body = AnalyzeRequest(userId: AppSettings.userID, dream: DreamEntryDTO(dream))
        let data = try await post("/api/v1/dreams/analyze", body: body)
        return try Self.decoder.decode(AnalyzeResponse.self, from: data).analysis
    }

    private func post(_ path: String, body: some Encodable) async throws -> Data {
        let trimmed = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        guard let url = URL(string: trimmed + path) else { throw AnalysisError.invalidURL(baseURL) }
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try Self.encoder.encode(body)

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            if let err = try? Self.decoder.decode(APIErrorResponse.self, from: data) {
                throw AnalysisError.server(code: err.error.code, message: err.error.message)
            }
            throw AnalysisError.badStatus(status)
        }
        return data
    }
}
