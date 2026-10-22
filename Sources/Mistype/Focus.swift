import AppKit
import ApplicationServices

enum Focus {
    /// Whether Accessibility is really granted right now. AXIsProcessTrusted() alone isn't enough:
    /// after Mistype is removed from the Accessibility list while running, it kept answering yes,
    /// the key tap stayed in place without permission, and the Mac's keyboard input froze (BUG-007).
    /// A real Accessibility call is refused at once (kAXErrorCannotComplete / APIDisabled).
    static func accessibilityWorks() -> Bool {
        guard AXIsProcessTrusted() else { return false }
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.2)
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(system, kAXFocusedApplicationAttribute as CFString, &value)
        return result == .success || result == .noValue
    }

    /// Whether the focused field is a password field. Read through Accessibility, because
    /// a web page's password field doesn't always turn on macOS secure input.
    static func isPasswordField() -> Bool {
        guard let focused = focusedElement() else { return false }
        var subrole: CFTypeRef?
        AXUIElementCopyAttributeValue(focused, kAXSubroleAttribute as CFString, &subrole)
        return subrole as? String == kAXSecureTextFieldSubrole
    }

    /// Whether the field being typed into has selected text. Right after typing that's an inline autocomplete
    /// (Spotlight, address bars): the first Delete removes it instead of a letter.
    /// Spotlight never becomes the frontmost app, so its search field isn't the system's focused element;
    /// it's asked directly too.
    static func hasSelection() -> Bool {
        var fields = [focusedElement()]
        if let spotlight = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Spotlight").first {
            let app = AXUIElementCreateApplication(spotlight.processIdentifier)
            AXUIElementSetMessagingTimeout(app, 0.05)
            var focused: CFTypeRef?
            if AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
               let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() {
                fields.append((focused as! AXUIElement))
            }
        }
        for case let field? in fields {
            var value: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(field, kAXSelectedTextRangeAttribute as CFString, &value)
            var range = CFRange()
            let selected = result == .success && value.map { CFGetTypeID($0) == AXValueGetTypeID() } == true
                && AXValueGetValue(value as! AXValue, .cfRange, &range) && range.length > 0
            log.notice("autocomplete check: result \(result.rawValue), selection \(range.location),\(range.length)")
            if selected { return true }
        }
        return false
    }

    private static func focusedElement() -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.05)  // a hung app must not stall the key tap
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        return (focused as! AXUIElement)
    }

    /// The app that turned on secure keyboard input (a password prompt, Terminal's Secure Keyboard Entry),
    /// or nil. While it's on, macOS hides key presses from every other app, Mistype included.
    static func secureInputOwner() -> String? {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any],
              let pid = session["kCGSSessionSecureInputPID"] as? pid_t, pid != getpid() else { return nil }
        return NSRunningApplication(processIdentifier: pid)?.localizedName ?? "?"
    }
}
