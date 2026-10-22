import Foundation

/// A word the user never wants switched automatically.
public struct Rule: Codable, Identifiable, Equatable, Sendable {
    public enum Match: String, Codable, CaseIterable, Sendable {
        case whole, prefix, contains
    }

    public var id = UUID()
    public var text: String
    public var match: Match
    public var caseSensitive: Bool
    public var enabled: Bool

    public init(text: String, match: Match = .whole, caseSensitive: Bool = false, enabled: Bool = true) {
        self.text = text
        self.match = match
        self.caseSensitive = caseSensitive
        self.enabled = enabled
    }

    /// Whether this rule keeps `word` as typed. The rule may be written in either layout,
    /// so it's checked against the word and against the word converted to the other layout.
    public func blocks(_ word: String) -> Bool {
        guard enabled, !text.isEmpty else { return false }
        return [word, Converter.convert(word)].contains { candidate in
            let a = caseSensitive ? candidate : candidate.lowercased()
            let b = caseSensitive ? text : text.lowercased()
            switch match {
            case .whole: return a == b
            case .prefix: return a.hasPrefix(b)
            case .contains: return a.contains(b)
            }
        }
    }
}

extension Array where Element == Rule {
    public func block(_ word: String) -> Bool { contains { $0.blocks(word) } }

    /// Whether another rule already has the same text and match (ignoring case unless both are case-sensitive).
    public func hasDuplicate(of rule: Rule) -> Bool {
        contains { other in
            other.id != rule.id && other.match == rule.match
                && (rule.caseSensitive && other.caseSensitive
                    ? other.text == rule.text
                    : other.text.lowercased() == rule.text.lowercased())
        }
    }
}
