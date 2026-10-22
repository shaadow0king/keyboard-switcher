import AppKit
import ApplicationServices
import SwiftUI

/// S02: explains why Switcher needs Accessibility, opens the right pane, and closes itself once it's granted.
/// An AppKit window (not a SwiftUI scene) so the app delegate can open and close it without a view's openWindow.
final class PermissionWindow {
    static let shared = PermissionWindow()
    private var window: NSWindow?

    func show(_ app: AppDelegate) {
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: PermissionView(app: app)))
            window.title = String(localized: "Switcher Permission")
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
        window = nil
    }

    /// Adds Switcher to the Accessibility list (macOS also shows its own short alert) and opens that pane,
    /// so the user only has to turn the switch on.
    static func openSettings() {
        AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
}

struct PermissionView: View {
    @ObservedObject var app: AppDelegate

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "keyboard")
                    .font(.system(size: 32))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text("Switcher needs Accessibility access")
                    .font(.title2.bold())
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("To notice a word typed in the wrong layout and retype it, Switcher has to see your key presses. They stay on this Mac: nothing is saved or sent anywhere, and password fields are skipped.")
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 6) {
                Text("1. Click Open System Settings.")
                Text("2. Turn on Switcher in the list. If it isn't there, click + and choose Switcher.")
                Text("3. Come back: this window closes by itself.")
            }
            .fixedSize(horizontal: false, vertical: true)
            Group {
                if app.hasPermission {
                    Label("Switcher is on.", systemImage: "checkmark.circle.fill")
                        .symbolRenderingMode(.multicolor)
                } else {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Waiting for permission…")
                    }
                }
            }
            .accessibilityElement(children: .combine)
            HStack {
                Spacer()
                Button("Later") { PermissionWindow.shared.close() }
                    .keyboardShortcut(.cancelAction)
                Button("Open System Settings") { PermissionWindow.openSettings() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(app.hasPermission)
            }
        }
        .padding(24)
        .frame(width: 460)
    }
}
