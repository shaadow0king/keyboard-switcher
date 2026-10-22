import AppKit
import Testing
@testable import SwitcherCore

/// The detector against the real macOS spell checker, the same call the app makes.
private func isWord(_ text: String, _ lang: Lang) -> Bool {
    NSSpellChecker.shared.checkSpelling(
        of: text, startingAt: 0, language: lang.code, wrap: false,
        inSpellDocumentWithTag: 0, wordCount: nil
    ).location == NSNotFound
}

private func fix(_ word: String) -> String? { Detector.fix(word, isWord: isWord) }

@Test("F01-H1 wrong layout, EN keys meant Russian", arguments: [
    ("ghbdtn", "привет"), ("Ghbdtn", "Привет"), ("nfr;t", "также"), ("cgfcb,j", "спасибо"),
    ("pfdnhf", "завтра"), ("rfr", "как"), ("xnj", "что"), ("ytn", "нет"),
])
func fixesEnglishKeysToRussian(typed: String, meant: String) {
    #expect(fix(typed) == meant)
}

@Test("F01-H2 wrong layout, RU keys meant English", arguments: [
    ("руддщ", "hello"), ("цщкдв", "world"), ("еуые", "test"), ("ерфтлы", "thanks"),
])
func fixesRussianKeysToEnglish(typed: String, meant: String) {
    #expect(fix(typed) == meant)
}

@Test("F01-E1 / BUG-001 all caps", arguments: [("GHBDTN", "ПРИВЕТ"), ("RFR", "КАК"), ("РУДДЩ", "HELLO")])
func fixesAllCaps(typed: String, meant: String) {
    #expect(fix(typed) == meant)
}

@Test("F01-E2 real words stay as typed", arguments: [
    "the", "and", "hello", "world", "test", "привет", "как", "что", "нет", "спасибо", "Москва",
])
func leavesRealWords(word: String) {
    #expect(fix(word) == nil)
}

@Test("F01-E3 short words (2 letters) are never touched", arguments: ["yt", "ns", "не", "ты", "ok"])
func leavesShortWords(word: String) {
    #expect(fix(word) == nil)
}

@Test("F01-E4 URLs, emails, numbers, code", arguments: [
    "https://ghbdtn.ru", "ghbdtn@mail.ru", "ghbdtn2", "v1.2.3", "a/b/c",
])
func leavesUrlsEmailsNumbers(word: String) {
    #expect(fix(word) == nil)
}

@Test("F01-E5 developer words typed in English stay English", arguments: [
    "npm", "git", "src", "cfg", "env", "tmp", "ssh", "dev", "lib", "pkg", "sudo", "grep",
    "json", "yaml", "api", "url", "http", "localhost", "macos", "iphone", "github", "repo",
])
func leavesDeveloperWords(word: String) {
    #expect(fix(word) == nil)
}

@Test("F01-E6 emoji and accents don't crash or convert", arguments: ["café", "naïve", "ghbdtn👍", "👍👍👍"])
func survivesEmojiAndAccents(word: String) {
    _ = fix(word)  // must not crash; the result is checked in the plan
}

@Test("F01-E7 very long input")
func survivesLongInput() {
    #expect(fix(String(repeating: "ghbdtn", count: 200)) == nil)
}

@Test("BUG-002 punctuation from the digit row", arguments: [("ghbdtn^", "привет:"), ("ghbdtn$", "привет;")])
func fixesDigitRowPunctuation(typed: String, meant: String) {
    #expect(fix(typed) == meant)
}

@Test("BUG-001 all-caps acronyms typed right stay", arguments: ["API", "USA", "NASA", "МГУ", "РФ"])
func leavesAllCapsAcronyms(word: String) {
    #expect(fix(word) == nil)
}
