import AppKit
import ApplicationServices
import Carbon.HIToolbox
import MistypeCore

/// Converts the selected text in the frontmost app to the other layout.
enum Selection {
    static func convert() {
        if convertWithAccessibility() { return }
        convertWithClipboard()
    }

    /// Native text views let us read and replace the selection directly.
    private static func convertWithAccessibility() -> Bool {
        var focused: CFTypeRef?
        let focusResult = AXUIElementCopyAttributeValue(AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute as CFString, &focused)
        guard focusResult == .success, let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else {
            log.notice("selection AX: no focused element (\(focusResult.rawValue))")
            return false
        }
        let element = focused as! AXUIElement
        var selected: CFTypeRef?
        let readResult = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selected)
        guard readResult == .success, let text = selected as? String, !text.isEmpty else {
            log.notice("selection AX: no selected text (\(readResult.rawValue))")
            return false
        }
        let converted = Converter.convert(text)
        let writeResult = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, converted as CFString)
        log.notice("selection AX: \(text.count) chars, write result \(writeResult.rawValue)")
        guard writeResult == .success else { return false }
        Layouts.select(Converter.lang(of: converted))
        return true
    }

    /// Everywhere else: copy, convert, paste, then put the user's clipboard back.
    private static func convertWithClipboard() {
        let board = NSPasteboard.general
        let saved: [NSPasteboardItem] = board.pasteboardItems?.map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
        } ?? []
        let before = board.changeCount
        Typist.command(kVK_ANSI_C)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            // Nothing copied means nothing was selected: leave the clipboard alone.
            log.notice("selection clipboard: copied=\(board.changeCount != before) chars=\(board.string(forType: .string)?.count ?? -1)")
            guard board.changeCount != before, let text = board.string(forType: .string), !text.isEmpty else { return }
            let converted = Converter.convert(text)
            board.clearContents()
            board.setString(converted, forType: .string)
            Typist.command(kVK_ANSI_V)
            Layouts.select(Converter.lang(of: converted))
            // shortcut: restores after a fixed delay; something copied within it is overwritten. Upgrade: watch changeCount.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                board.clearContents()
                board.writeObjects(saved)
            }
        }
    }
}
