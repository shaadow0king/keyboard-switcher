import AppKit
import ApplicationServices

enum Focus {
    /// Whether the focused field is a password field. Read through Accessibility, because
    /// a web page's password field doesn't always turn on macOS secure input.
    static func isPasswordField() -> Bool {
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.05)  // a hung app must not stall the key tap
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return false }
        var subrole: CFTypeRef?
        AXUIElementCopyAttributeValue(focused as! AXUIElement, kAXSubroleAttribute as CFString, &subrole)
        return subrole as? String == kAXSecureTextFieldSubrole
    }

    /// The app that turned on secure keyboard input (a password prompt, Terminal's Secure Keyboard Entry),
    /// or nil. While it's on, macOS hides key presses from every other app, Switcher included.
    static func secureInputOwner() -> String? {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any],
              let pid = session["kCGSSessionSecureInputPID"] as? pid_t, pid != getpid() else { return nil }
        return NSRunningApplication(processIdentifier: pid)?.localizedName ?? "?"
    }
}
