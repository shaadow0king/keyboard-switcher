import AppKit
import Carbon.HIToolbox
import OSLog
import SwitcherCore

/// Key codes and events only, never the typed text. Read with: log stream --predicate 'subsystem == "local.switcher"'
let log = Logger(subsystem: "local.switcher", category: "tap")

/// Watches every key press: fixes a word when a space ends it, and runs the convert hotkey.
final class KeyTap {
    static let shared = KeyTap()
    /// Tags the events we post ourselves so the tap lets them through untouched.
    static let marker: Int64 = 0x5357_4954

    private var tap: CFMachPort?
    /// Clicks only reset the word, so they go through a listen-only tap: the mouse never waits for us.
    private var mouseTap: CFMachPort?
    private var sources: [CFRunLoopSource] = []
    private var typed = TypedText()
    /// A modifier pressed with nothing else held; it fires as a hotkey if released before any other key.
    private var pendingModifier: Int?
    private let prefs = Prefs.shared
    private var appObserver: NSObjectProtocol?
    private var inPasswordField = false

    var isRunning: Bool { tap != nil }

    func start() -> Bool {
        if tap != nil { return true }
        let keys: CGEventMask = 1 << CGEventType.keyDown.rawValue | 1 << CGEventType.flagsChanged.rawValue
        let clicks: CGEventMask = 1 << CGEventType.leftMouseDown.rawValue | 1 << CGEventType.rightMouseDown.rawValue
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: keys,
            callback: { _, type, event, _ in
                KeyTap.shared.handle(type, event).map { Unmanaged.passUnretained($0) }
            },
            userInfo: nil
        ) else { return false }
        self.tap = tap
        mouseTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .listenOnly,
            eventsOfInterest: clicks,
            callback: { _, type, event, _ in
                KeyTap.shared.handle(type, event).map { Unmanaged.passUnretained($0) }
            },
            userInfo: nil
        )
        for port in [tap, mouseTap].compactMap({ $0 }) {
            let source = CFMachPortCreateRunLoopSource(nil, port, 0)!
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            sources.append(source)
            CGEvent.tapEnable(tap: port, enable: true)
        }
        appObserver = appObserver ?? NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.typed.reset()  // another app is frontmost: the cursor is somewhere else now
        }
        log.notice("tap started, hotkey=\(self.prefs.hotkey.label)")
        // Load both dictionaries now: a slow first lookup inside the tap gets the tap disabled.
        _ = Spelling.isWord("test", .en) || Spelling.isWord("тест", .ru)
        return true
    }

    /// Removes the taps. Must run as soon as Accessibility is revoked: an active tap
    /// left behind without permission can freeze keyboard input for the whole Mac.
    func stop() {
        for port in [tap, mouseTap].compactMap({ $0 }) {
            CGEvent.tapEnable(tap: port, enable: false)
            CFMachPortInvalidate(port)
        }
        for source in sources { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if tap != nil { log.notice("tap stopped") }
        tap = nil
        mouseTap = nil
        sources = []
        typed.reset()
        pendingModifier = nil
    }

    /// Runs on the main thread for every event. Returning nil swallows the event.
    private func handle(_ type: CGEventType, _ event: CGEvent) -> CGEvent? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            typed.reset()
            return event
        case .flagsChanged:
            flagsChanged(event)
            return event
        case .keyDown:
            pendingModifier = nil
            if event.getIntegerValueField(.eventSourceUserData) == Self.marker { return event }
            return keyDown(event)
        default:
            pendingModifier = nil
            typed.reset()  // a click may have moved the cursor
            return event
        }
    }

    private func flagsChanged(_ event: CGEvent) {
        let key = Int(event.getIntegerValueField(.keyboardEventKeycode))
        guard let modifier = Hotkey.modifierKeys[key] else { pendingModifier = nil; return }
        let held = event.flags.intersection(Hotkey.modifierMask.union(.maskSecondaryFn))
        log.notice("flags key=\(key) held=\(held.rawValue, format: .hex) raw=\(event.flags.rawValue, format: .hex) pending=\(self.pendingModifier ?? -1)")
        if held == modifier.flag {
            pendingModifier = key  // pressed alone
        } else if held.isEmpty, pendingModifier == key {
            pendingModifier = nil  // released alone
            if prefs.recording {
                prefs.hotkey = Hotkey(keyCode: key, modifiers: 0, modifierOnly: true, label: modifier.label)
                prefs.recording = false
            } else if prefs.hotkey.matchesModifier(key) {
                convert()
            }
        } else {
            pendingModifier = nil
        }
    }

    private func keyDown(_ event: CGEvent) -> CGEvent? {
        let key = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let text = typedText(event)

        if prefs.recording {
            let commandLike = !event.flags.isDisjoint(with: [.maskCommand, .maskControl, .maskAlternate])
            if key == kVK_Escape && !commandLike {
                prefs.recording = false
            } else if commandLike || Hotkey.functionKeys.contains(key) {
                // Plain letters, Space or Return would make a hotkey you can't type with.
                prefs.hotkey = .combo(event)
                prefs.recording = false
            }
            return nil
        }
        if prefs.hotkey.matches(event) {
            convert()
            return nil
        }

        if !event.flags.isDisjoint(with: [.maskCommand, .maskControl, .maskAlternate]) {
            typed.reset()
            return event
        }

        switch key {
        case kVK_Delete:
            typed.backspace()
            return event
        case kVK_Space:
            guard let ended = typed.space() else { return event }
            return fixEnded(ended) ? nil : event
        default:
            break
        }

        // Arrows, Return, Tab, Esc and other non-text keys end the word without fixing it.
        guard let text, isPrintable(text) else {
            typed.reset()
            return event
        }
        // Asked once per word: a password is never kept, not even in memory.
        if typed.word.isEmpty { inPasswordField = Focus.isPasswordField() }
        if inPasswordField {
            typed.reset()
            return event
        }
        typed.type(text)
        return event
    }

    /// A space just ended `ended` (the space itself is held back). Fixes the word if it's in the wrong layout,
    /// together with the short words right before it that were typed in the same wrong layout.
    /// Returns true when it retyped, and the held space is part of the retyped text.
    private func fixEnded(_ ended: String) -> Bool {
        guard prefs.autoSwitch, !prefs.rules.block(ended) else { return false }
        guard let fixed = Detector.fix(ended, isWord: Spelling.isWord)
            ?? Detector.fixShort(ended, after: nil, isWord: Spelling.isWord) else { return false }
        let to = Converter.lang(of: fixed)
        let last = typed.done.count - 1
        var first = last
        var retyped: [Int: String] = [:]
        while first > 0 {
            let earlier = typed.done[first - 1].text
            guard !prefs.rules.block(earlier),
                  let short = Detector.fixShort(earlier, after: to, isWord: Spelling.isWord) else { break }
            first -= 1
            retyped[first] = short
        }
        var erase = ended.count
        var text = ""
        for i in first..<last {
            let word = typed.done[i]
            erase += word.text.count + word.spaces.count
            text += (retyped[i] ?? word.text) + word.spaces
            typed.replaceDone(i, with: retyped[i] ?? word.text)
        }
        Typist.replace(count: erase, with: text + fixed + " ")
        typed.replaceTarget(with: fixed)
        Layouts.select(to)
        return true
    }

    /// The hotkey: retypes the word just typed in the other layout, or converts the selection.
    /// Pressing it again converts back, which also undoes an automatic fix.
    private func convert() {
        log.notice("convert: target=\(self.typed.target?.text.count ?? -1) chars")
        guard !Focus.isPasswordField() else { return }
        guard let target = typed.target else {
            Selection.convert()
            return
        }
        let converted = Converter.convert(target.text)
        Typist.replace(count: target.text.count + target.spaces.count, with: converted + target.spaces)
        typed.replaceTarget(with: converted)
        Layouts.select(Converter.lang(of: converted))
    }

    private func typedText(_ event: CGEvent) -> String? {
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(maxStringLength: chars.count, actualStringLength: &length, unicodeString: &chars)
        return length > 0 ? String(utf16CodeUnits: chars, count: length) : nil
    }

    private func isPrintable(_ text: String) -> Bool {
        text.unicodeScalars.allSatisfy { !CharacterSet.controlCharacters.contains($0) && !(0xE000...0xF8FF).contains($0.value) }
    }
}

enum Typist {
    /// Erases `count` characters before the cursor and types `text` in their place.
    static func replace(count: Int, with text: String) {
        let source = CGEventSource(stateID: .privateState)  // a Shift the user still holds doesn't leak in
        for _ in 0..<count { press(source, key: CGKeyCode(kVK_Delete)) }
        for unit in text.utf16 {
            press(source, key: CGKeyCode(unit == 0x20 ? kVK_Space : 0), unicode: [unit])
        }
    }

    /// Presses ⌘ + `key`, e.g. kVK_ANSI_C to copy.
    static func command(_ key: Int) {
        press(CGEventSource(stateID: .privateState), key: CGKeyCode(key), flags: .maskCommand)
    }

    private static func press(_ source: CGEventSource?, key: CGKeyCode, unicode: [UniChar] = [], flags: CGEventFlags = []) {
        for down in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down) else { continue }
            event.flags = flags
            if !unicode.isEmpty { event.keyboardSetUnicodeString(stringLength: unicode.count, unicodeString: unicode) }
            event.setIntegerValueField(.eventSourceUserData, value: KeyTap.marker)
            event.post(tap: .cgSessionEventTap)
        }
    }
}

enum Spelling {
    static func isWord(_ text: String, _ lang: Lang) -> Bool {
        NSSpellChecker.shared.checkSpelling(
            of: text, startingAt: 0, language: lang.code, wrap: false,
            inSpellDocumentWithTag: 0, wordCount: nil
        ).location == NSNotFound
    }
}

enum Layouts {
    /// "RU" or "EN" for the active keyboard layout, nil for anything else.
    static func currentCode() -> String? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let raw = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages) else { return nil }
        let lang = (Unmanaged<CFArray>.fromOpaque(raw).takeUnretainedValue() as? [String])?.first ?? ""
        return lang.hasPrefix("ru") ? "RU" : lang.hasPrefix("en") ? "EN" : nil
    }

    /// Selects the first enabled keyboard layout whose main language is `lang`.
    static func select(_ lang: Lang) {
        let filter = [
            kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource as String,
            kTISPropertyInputSourceIsSelectCapable as String: true,
        ] as CFDictionary
        guard let sources = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource] else { return }
        let match = sources.first { source in
            guard let raw = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages) else { return false }
            let langs = Unmanaged<CFArray>.fromOpaque(raw).takeUnretainedValue() as? [String] ?? []
            return langs.first == lang.code
        }
        if let match { TISSelectInputSource(match) }
    }
}
