import AppKit
import Carbon.HIToolbox

/// A user-chosen key: either a modifier pressed and released alone (⌥), or a key with modifiers (⌃⌥Space).
struct Hotkey: Codable, Equatable {
    var keyCode: Int
    var modifiers: UInt64  // CGEventFlags raw value, only for key combos
    var modifierOnly: Bool
    var label: String
    /// A modifier-only hotkey that fires from the left or the right key. Optional so older saved hotkeys still decode.
    var anySide: Bool?

    static let option = Hotkey(keyCode: kVK_Option, modifiers: 0, modifierOnly: true, label: "⌥ (left or right)", anySide: true)

    /// Whether releasing modifier `key` alone fires this hotkey.
    func matchesModifier(_ key: Int) -> Bool {
        guard modifierOnly else { return false }
        if key == keyCode { return true }
        return anySide == true && Self.modifierKeys[key]?.flag == Self.modifierKeys[keyCode]?.flag
    }

    /// Flags that count for matching; Caps Lock and the rest are ignored.
    static let modifierMask: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift]

    /// Keys that can be a hotkey on their own, with the flag each one sets.
    static let modifierKeys: [Int: (flag: CGEventFlags, label: String)] = [
        kVK_RightOption: (.maskAlternate, "Right ⌥"), kVK_Option: (.maskAlternate, "Left ⌥"),
        kVK_RightCommand: (.maskCommand, "Right ⌘"), kVK_Command: (.maskCommand, "Left ⌘"),
        kVK_RightShift: (.maskShift, "Right ⇧"), kVK_Shift: (.maskShift, "Left ⇧"),
        kVK_RightControl: (.maskControl, "Right ⌃"), kVK_Control: (.maskControl, "Left ⌃"),
        kVK_Function: (.maskSecondaryFn, "fn"),
    ]

    /// F1–F19: the only keys allowed as a hotkey without ⌘, ⌃ or ⌥.
    static let functionKeys: Set<Int> = [
        kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
        kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19,
    ]

    static func combo(_ event: CGEvent) -> Hotkey {
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags.intersection(modifierMask)
        var label = ""
        if flags.contains(.maskControl) { label += "⌃" }
        if flags.contains(.maskAlternate) { label += "⌥" }
        if flags.contains(.maskShift) { label += "⇧" }
        if flags.contains(.maskCommand) { label += "⌘" }
        label += keyNames[keyCode] ?? NSEvent(cgEvent: event)?.charactersIgnoringModifiers?.uppercased() ?? "#\(keyCode)"
        return Hotkey(keyCode: keyCode, modifiers: flags.rawValue, modifierOnly: false, label: label)
    }

    func matches(_ event: CGEvent) -> Bool {
        !modifierOnly
            && Int(event.getIntegerValueField(.keyboardEventKeycode)) == keyCode
            && event.flags.intersection(Self.modifierMask).rawValue == modifiers
    }

    private static let keyNames: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_Home: "Home", kVK_End: "End", kVK_PageUp: "Page Up", kVK_PageDown: "Page Down",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15", kVK_F16: "F16", kVK_F17: "F17",
        kVK_F18: "F18", kVK_F19: "F19",
    ]
}

/// Settings, saved in UserDefaults. Read by the key tap on the main thread.
final class Prefs: ObservableObject {
    static let shared = Prefs()
    private let defaults = UserDefaults.standard

    @Published var autoSwitch: Bool {
        didSet { defaults.set(autoSwitch, forKey: "autoSwitch") }
    }
    @Published var hotkey: Hotkey {
        didSet { defaults.set(try? JSONEncoder().encode(hotkey), forKey: "convertHotkey") }
    }
    /// While true, the next hotkey-worthy key press becomes the hotkey instead of acting.
    @Published var recording = false
    @Published var settingsTab = SettingsTab.general

    private init() {
        autoSwitch = defaults.object(forKey: "autoSwitch") as? Bool ?? true
        hotkey = defaults.data(forKey: "convertHotkey").flatMap { try? JSONDecoder().decode(Hotkey.self, from: $0) } ?? .option
    }
}
