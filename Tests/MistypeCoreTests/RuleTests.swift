import Testing
@testable import MistypeCore

@Test func wholeWordMatchesInEitherLayout() {
    let rule = Rule(text: "ghbdtn")
    #expect(rule.blocks("ghbdtn"))
    #expect(rule.blocks("Ghbdtn"))      // case-insensitive by default
    #expect(rule.blocks("привет"))      // same keys, other layout
    #expect(!rule.blocks("ghbdtnf"))
}

@Test func prefixAndContains() {
    #expect(Rule(text: "http", match: .prefix).blocks("https"))
    #expect(!Rule(text: "http", match: .prefix).blocks("xhttp"))
    #expect(Rule(text: "dev", match: .contains).blocks("mydevice"))
}

@Test func caseSensitiveAndDisabled() {
    #expect(!Rule(text: "API", caseSensitive: true).blocks("api"))
    #expect(Rule(text: "API", caseSensitive: true).blocks("API"))
    #expect(!Rule(text: "api", enabled: false).blocks("api"))
    #expect(!Rule(text: "").blocks("anything"))
}

@Test func duplicates() {
    let a = Rule(text: "Word")
    let rules = [a]
    #expect(rules.hasDuplicate(of: Rule(text: "word")))
    #expect(!rules.hasDuplicate(of: Rule(text: "word", match: .prefix)))
    #expect(!rules.hasDuplicate(of: a))  // editing itself
    #expect(rules.block("WORD"))
}
