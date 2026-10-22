public enum Lang: Sendable {
    case en, ru

    public var other: Lang { self == .en ? .ru : .en }
    public var code: String { self == .en ? "en" : "ru" }
}

/// Maps text between the US/ABC and Russian keyboards by key position.
public enum Converter {
    // shortcut: positions of "Russian – PC"; the Mac "Russian" layout moves ё and some punctuation, add a table if you use it.
    static let en = Array("`qwertyuiop[]asdfghjkl;'zxcvbnm,./~QWERTYUIOP{}ASDFGHJKL:\"ZXCVBNM<>?")
    static let ru = Array("ёйцукенгшщзхъфывапролджэячсмитьбю.ЁЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮ,")
    static let enToRu = Dictionary(uniqueKeysWithValues: zip(en, ru))
    static let ruToEn = Dictionary(uniqueKeysWithValues: zip(ru, en))

    public static func lang(of text: String) -> Lang {
        text.unicodeScalars.contains { (0x0400...0x04FF).contains($0.value) } ? .ru : .en
    }

    public static func convert(_ text: String) -> String {
        let map = lang(of: text) == .ru ? ruToEn : enToRu
        return String(text.map { map[$0] ?? $0 })
    }
}

public enum Detector {
    /// The word retyped in the other layout, or nil to leave it as typed.
    public static func fix(_ word: String, isWord: (String, Lang) -> Bool) -> String? {
        guard word.count >= 3,
              !word.contains(where: \.isNumber),
              !word.contains("@"), !word.contains("://") else { return nil }
        let from = Converter.lang(of: word)
        let converted = Converter.convert(word)
        guard converted.contains(where: \.isLetter),
              !isWord(word, from),
              isWord(converted, from.other) else { return nil }
        return converted
    }
}
