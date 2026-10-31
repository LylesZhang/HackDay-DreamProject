import SwiftUI

/// 用户自定义的关键词，每个关键词有自己的档案（profile）。
/// 记录里出现它的名字或别名时会自动链接过来，类似 Obsidian 的双链，但只链接到关键词。
struct Keyword: Identifiable, Codable, Hashable {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case person, imagery, scene
        var id: String { rawValue }

        var label: String {
            switch self {
            case .person: "People"
            case .imagery: "Symbols"
            case .scene: "Life stages · Scenes"
            }
        }

        var shortLabel: String {
            switch self {
            case .person: "Person"
            case .imagery: "Symbol"
            case .scene: "Scene"
            }
        }

        var icon: String {
            switch self {
            case .person: "person.fill"
            case .imagery: "sparkle"
            case .scene: "signpost.right.fill"
            }
        }

        var color: Color {
            switch self {
            case .person: Color(hex: 0xFF9FB8)
            case .imagery: NightPalette.accent
            case .scene: Color(hex: 0x7DD3C8)
            }
        }

        var namePlaceholder: String {
            switch self {
            case .person: "Name, e.g. Grandma"
            case .imagery: "Symbol, e.g. Whale"
            case .scene: "Stage or scene, e.g. High school"
            }
        }

        var subtitlePlaceholder: String {
            switch self {
            case .person: "Who they are, e.g. raised me as a kid"
            case .imagery: "How it feels, e.g. quiet and huge"
            case .scene: "Rough time or place, e.g. 2015–2018, hometown"
            }
        }
    }

    var id = UUID()
    var name: String
    var kind: Kind
    /// 一句话介绍
    var subtitle: String = ""
    /// 更长的备注
    var note: String = ""
    /// 别名：记录里出现别名也会链接到这个关键词
    var aliases: [String] = []
    var createdAt = Date()

    /// 参与匹配的词：名字 + 别名
    var terms: [String] {
        ([name] + aliases).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    func isMentioned(in text: String) -> Bool {
        terms.contains { !Self.ranges(of: $0, in: text).isEmpty }
    }

    /// 词在文本里出现的位置。英文按整词匹配（允许复数 s / es，“cat” 不会匹配 “category”），
    /// 其他文字按子串匹配。不区分大小写。
    static func ranges(of term: String, in text: String) -> [Range<String.Index>] {
        let escaped = NSRegularExpression.escapedPattern(for: term)
        let isLatin = term.unicodeScalars.allSatisfy(\.isASCII)
        let pattern = isLatin ? "\\b\(escaped)(?:s|es)?\\b" : escaped
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { Range($0.range, in: text) }
    }
}

/// AI 从最近几天的梦里提炼出的关键词建议
struct KeywordSuggestion: Identifiable, Codable, Hashable {
    var name: String
    var kind: Keyword.Kind
    var reason: String
    var id: String { name }
}

struct KeywordSuggestionBatch: Codable {
    var suggestions: [KeywordSuggestion]
    var generatedAt: Date
    /// 生成时依据的最近梦境签名；梦有变化时才重新生成
    var basedOn: String
    var source: DreamAnalysis.Source
}

/// 把文本里出现的关键词标成可点击的链接
enum KeywordLinker {
    private static let host = "keyword"

    static func url(for keyword: Keyword) -> URL {
        URL(string: "dreamjournal://\(host)/\(keyword.id.uuidString)")!
    }

    static func keywordID(from url: URL) -> UUID? {
        guard url.scheme == "dreamjournal", url.host == host else { return nil }
        return UUID(uuidString: url.lastPathComponent)
    }

    static func attributed(_ text: String, keywords: [Keyword]) -> AttributedString {
        var result = AttributedString(text)
        // 长词优先，避免“奶奶家”被“奶奶”抢先匹配
        let pairs = keywords.flatMap { k in k.terms.map { ($0, k) } }.sorted { $0.0.count > $1.0.count }
        var taken: [Range<String.Index>] = []
        for (term, keyword) in pairs {
            for r in Keyword.ranges(of: term, in: text) where !taken.contains(where: { $0.overlaps(r) }) {
                guard let ar = Range(r, in: result) else { continue }
                taken.append(r)
                result[ar].link = url(for: keyword)
                result[ar].foregroundColor = keyword.kind.color
                result[ar].backgroundColor = keyword.kind.color.opacity(0.14)
            }
        }
        return result
    }

    /// 把关键词接到记录末尾（用逗号衔接）
    static func append(_ word: String, to text: inout String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed.hasSuffix("\n") {
            text = trimmed + word
        } else if let last = trimmed.last, ",.!?;:".contains(last) {
            text = trimmed + " " + word
        } else {
            text = trimmed + ", " + word
        }
    }
}
