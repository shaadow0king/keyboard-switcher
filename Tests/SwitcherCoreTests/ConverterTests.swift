import Testing
@testable import SwitcherCore

private let words: Set<String> = ["привет", "Привет", "также", "hello"]
private func isWord(_ s: String, _: Lang) -> Bool { words.contains(s) }

@Test func tablesLineUp() {
    #expect(Converter.en.count == Converter.ru.count)
    #expect(Converter.enToRu.count == Converter.en.count)
    #expect(Converter.ruToEn.count == Converter.ru.count)
}

@Test func convertsBothWays() {
    #expect(Converter.convert("ghbdtn") == "привет")
    #expect(Converter.convert("Ghbdtn") == "Привет")
    #expect(Converter.convert("nfr;t") == "также")
    #expect(Converter.convert("руддщ") == "hello")
}

@Test func fixesWrongLayout() {
    #expect(Detector.fix("ghbdtn", isWord: isWord) == "привет")
    #expect(Detector.fix("Ghbdtn", isWord: isWord) == "Привет")
    #expect(Detector.fix("руддщ", isWord: isWord) == "hello")
}

@Test func leavesEverythingElse() {
    #expect(Detector.fix("hello", isWord: isWord) == nil)   // already a word
    #expect(Detector.fix("zzzz", isWord: isWord) == nil)    // neither is a word
    #expect(Detector.fix("gh", isWord: isWord) == nil)      // too short
    #expect(Detector.fix("ghbdtn1", isWord: isWord) == nil)
    #expect(Detector.fix("a@ghbdtn", isWord: isWord) == nil)
}
