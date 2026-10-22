/// What was typed right before the cursor since the last click, arrow, Return or shortcut.
public struct TypedText {
    public private(set) var word = ""      // the word being typed
    public private(set) var lastWord = ""  // the word before it, ended by `spaces`
    public private(set) var spaces = ""

    public init() {}

    public mutating func type(_ text: String) {
        if word.isEmpty { lastWord = ""; spaces = "" }
        word += text
    }

    /// Ends the current word with a space. Returns that word, or nil if there was none.
    public mutating func space() -> String? {
        guard !word.isEmpty else {
            if !lastWord.isEmpty { spaces += " " }
            return nil
        }
        let ended = word
        lastWord = word
        spaces = " "
        word = ""
        return ended
    }

    public mutating func backspace() {
        if !word.isEmpty {
            word.removeLast()
        } else if !spaces.isEmpty {
            spaces.removeLast()
            if spaces.isEmpty { word = lastWord; lastWord = "" }  // the cursor is back at the end of that word
        } else {
            reset()  // deleting text we never saw
        }
    }

    public mutating func reset() {
        word = ""; lastWord = ""; spaces = ""
    }

    /// The text the hotkey converts, and the spaces typed after it.
    public var target: (text: String, spaces: String)? {
        if !word.isEmpty { return (word, "") }
        if !lastWord.isEmpty { return (lastWord, spaces) }
        return nil
    }

    /// Records that the target text was retyped as `text`.
    public mutating func replaceTarget(with text: String) {
        if !word.isEmpty { word = text } else { lastWord = text }
    }
}
