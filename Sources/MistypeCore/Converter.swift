public enum Lang: Sendable {
    case en, ru

    public var other: Lang { self == .en ? .ru : .en }
    public var code: String { self == .en ? "en" : "ru" }
}

/// Maps text between the US/ABC and Russian keyboards by key position.
public enum Converter {
    // shortcut: positions of "Russian – PC"; the Mac "Russian" layout moves ё and some punctuation, add a table if you use it.
    static let en = Array("`qwertyuiop[]asdfghjkl;'zxcvbnm,./~QWERTYUIOP{}ASDFGHJKL:\"ZXCVBNM<>?@#$^&")
    static let ru = Array("ёйцукенгшщзхъфывапролджэячсмитьбю.ЁЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮ,\"№;:?")
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
        // The spell checker takes any all-caps word for an acronym and accepts it,
        // so CAPS LOCK typing is checked in lowercase.
        let allCaps = word == word.uppercased() && word != word.lowercased()
        let check = allCaps ? { isWord($0.lowercased(), $1) } : isWord
        guard converted.contains(where: \.isLetter),
              !check(word, from),
              check(converted, from.other) else { return nil }
        return converted
    }
}

/// Common one- and two-letter words. Short words are too ambiguous for the spell checker alone,
/// so a short word is only ever retyped into one of these.
public enum ShortWords {
    static let ru: Set<String> = [
        "а", "в", "и", "к", "о", "с", "у", "я",
        "не", "на", "но", "ну", "да", "же", "бы", "ли", "мы", "вы", "он", "то", "по", "за", "из",
        "до", "от", "об", "во", "ко", "со", "ты", "уж", "ни", "её", "их", "им", "ей",
    ]
    static let en: Set<String> = [
        "a", "i",
        "am", "an", "as", "at", "be", "by", "do", "go", "he", "if", "in", "is", "it", "me", "my",
        "no", "of", "on", "or", "so", "to", "up", "us", "we",
    ]

    static func list(_ lang: Lang) -> Set<String> { lang == .ru ? ru : en }
}

extension Detector {
    /// A one- or two-letter word, retyped only into a common short word of the other language.
    /// `after`: the language the next word was just fixed into; then the short word follows it (`z ljvf` → я дома).
    /// Without it, only two-letter words that aren't words as typed are fixed: `yt` → не, but `vs` and `do` stay.
    public static func fixShort(_ word: String, after: Lang?, isWord: (String, Lang) -> Bool) -> String? {
        guard (1...3).contains(word.count), !word.contains(where: \.isNumber) else { return nil }
        let from = Converter.lang(of: word)
        let to = from.other
        let converted = Converter.convert(word)
        let core = converted.trimmingCharacters(in: .punctuationCharacters).lowercased()
        guard (1...2).contains(core.count), ShortWords.list(to).contains(core) else { return nil }
        if let after { return after == to ? converted : nil }
        guard core.count == 2,
              !ShortWords.list(from).contains(word.lowercased()),
              !isWord(word, from) else { return nil }
        return converted
    }
}
