import Testing
@testable import SwitcherCore

@Test func targetIsTheWordBeingTyped() {
    var t = TypedText()
    t.type("g"); t.type("h"); t.type("b")
    #expect(t.target?.text == "ghb")
    #expect(t.target?.spaces == "")
}

@Test func targetSurvivesSpacesAfterTheWord() {
    var t = TypedText()
    for c in "ghbdtn" { t.type(String(c)) }
    #expect(t.space() == "ghbdtn")
    #expect(t.space() == nil)
    #expect(t.target?.text == "ghbdtn")
    #expect(t.target?.spaces == "  ")
}

@Test func backspaceIntoTheWordResumesIt() {
    var t = TypedText()
    t.type("ab"); _ = t.space()
    t.backspace()
    #expect(t.word == "ab")
    t.type("c")
    #expect(t.target?.text == "abc")
}

@Test func newWordBecomesTheTargetAndOldOnesAreKept() {
    var t = TypedText()
    t.type("one"); _ = t.space(); t.type("t")
    #expect(t.target?.text == "t")
    #expect(t.done.map(\.text) == ["one"])
}

@Test func keepsOnlyTheLastFewWords() {
    var t = TypedText()
    for i in 0..<20 { t.type("w\(i)"); _ = t.space() }
    #expect(t.done.count == 8)
    #expect(t.done.last?.text == "w19")
}

@Test func replaceDoneRetypesAnEarlierWord() {
    var t = TypedText()
    t.type("z"); _ = t.space(); t.type("ljvf"); _ = t.space()
    t.replaceDone(0, with: "я")
    #expect(t.done.map(\.text) == ["я", "ljvf"])
}

@Test func replaceTargetTogglesBack() {
    var t = TypedText()
    t.type("ghbdtn"); _ = t.space()
    t.replaceTarget(with: Converter.convert(t.target!.text))
    #expect(t.target?.text == "привет")
    t.replaceTarget(with: Converter.convert(t.target!.text))
    #expect(t.target?.text == "ghbdtn")
}

@Test func resetAndUnseenDeletesClearEverything() {
    var t = TypedText()
    t.type("abc"); t.reset()
    #expect(t.target == nil)
    t.backspace()
    #expect(t.target == nil)
}
