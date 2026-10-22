/// Release versions like "0.2", "v1.10.3". Compared number by number, so 1.10 is newer than 1.9.
public struct Version: Comparable, CustomStringConvertible {
    public let parts: [Int]

    /// Accepts an optional leading "v" and ignores anything after the numbers ("1.2-beta" → 1.2).
    public init?(_ text: String) {
        var s = Substring(text.trimmingCharacters(in: .whitespaces))
        if s.first == "v" || s.first == "V" { s = s.dropFirst() }
        let numbers = s.prefix { $0.isNumber || $0 == "." }.split(separator: ".").compactMap { Int($0) }
        guard !numbers.isEmpty else { return nil }
        parts = numbers
    }

    public var description: String { parts.map(String.init).joined(separator: ".") }

    public static func < (a: Version, b: Version) -> Bool {
        for i in 0..<max(a.parts.count, b.parts.count) {
            let x = i < a.parts.count ? a.parts[i] : 0
            let y = i < b.parts.count ? b.parts[i] : 0
            if x != y { return x < y }
        }
        return false
    }

    public static func == (a: Version, b: Version) -> Bool { !(a < b) && !(b < a) }
}
