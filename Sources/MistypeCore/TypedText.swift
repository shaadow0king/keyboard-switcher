/// What was typed right before the cursor since the last click, arrow, Return or shortcut.
public struct TypedText {
    public struct Word: Equatable {
        public var text: String
        public var spaces: String  // typed after it
    }

    public private(set) var word = ""  // the word being typed
    /// Finished words before the cursor, oldest first. Only the last few are kept.
    public private(set) var done: [Word] = []
    static let keep = 8

    public init() {}

    public var spaces: String { done.last?.spaces ?? "" }

    public mutating func type(_ text: String) {
        word += text
    }

    /// Ends the current word with a space. Returns that word, or nil if there was none.
    public mutating func space() -> String? {
        guard !word.isEmpty else {
            if !done.isEmpty { done[done.count - 1].spaces += " " }
            return nil
        }
        let ended = word
        done.append(Word(text: word, spaces: " "))
        if done.count > Self.keep { done.removeFirst() }
        word = ""
        return ended
    }

    public mutating func backspace() {
        if !word.isEmpty {
            word.removeLast()
        } else if let last = done.last, !last.spaces.isEmpty {
            done[done.count - 1].spaces.removeLast()
            if done[done.count - 1].spaces.isEmpty {  // the cursor is back at the end of that word
                word = last.text
                done.removeLast()
            }
        } else {
            reset()  // deleting text we never saw
        }
    }

    public mutating func reset() {
        word = ""
        done = []
    }

    /// The text the hotkey converts, and the spaces typed after it.
    public var target: (text: String, spaces: String)? {
        if !word.isEmpty { return (word, "") }
        if let last = done.last { return (last.text, last.spaces) }
        return nil
    }

    /// Records that the target text was retyped as `text`.
    public mutating func replaceTarget(with text: String) {
        if !word.isEmpty { word = text } else if !done.isEmpty { done[done.count - 1].text = text }
    }

    /// Records that finished word `index` was retyped as `text`.
    public mutating func replaceDone(_ index: Int, with text: String) {
        done[index].text = text
    }
}
