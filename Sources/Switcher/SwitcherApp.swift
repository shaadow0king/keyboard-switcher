import ApplicationServices
import SwiftUI

@main
struct SwitcherApp: App {
    @NSApplicationDelegateAdaptor private var app: AppDelegate

    var body: some Scene {
        MenuBarExtra("Switcher", systemImage: "keyboard") {
            MenuView(app: app, prefs: .shared)
        }
        Window("Switcher Settings", id: "settings") {
            SettingsView(prefs: .shared)
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
    }
}

struct MenuView: View {
    // Passed in: MenuBarExtra content doesn't receive the delegate as an environment object.
    @ObservedObject var app: AppDelegate
    @ObservedObject var prefs: Prefs
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(app.status)
        Text("Convert: \(prefs.hotkey.label)")
        Divider()
        Toggle("Switch layout automatically", isOn: $prefs.autoSwitch)
        Button("Settings…") {
            openWindow(id: "settings")
            NSApp.activate()
        }
        .keyboardShortcut(",")
        Divider()
        Button("Quit Switcher") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

struct SettingsView: View {
    @ObservedObject var prefs: Prefs

    var body: some View {
        Form {
            Toggle("Switch layout automatically", isOn: $prefs.autoSwitch)
            LabeledContent("Convert hotkey") {
                HStack {
                    Text(prefs.recording ? "Press a key…" : prefs.hotkey.label)
                        .foregroundStyle(prefs.recording ? .secondary : .primary)
                    Button(prefs.recording ? "Cancel" : "Change…") { prefs.recording.toggle() }
                }
            }
            Text("""
                Retypes the word you just typed in the other layout, or the selected text. \
                Press it again to switch back; that also undoes an automatic fix.
                Use a modifier on its own (right ⌥), a key with ⌘ ⌃ or ⌥, or F1–F19. Esc cancels.
                """)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .onDisappear { prefs.recording = false }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published var status = "Starting…"
    private var retry: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if KeyTap.shared.start() {
            status = "Running"
            return
        }
        // The tap can't be created until the user grants Accessibility; ask once, then wait for it.
        status = "Needs Accessibility permission"
        AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        retry = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
            guard KeyTap.shared.start() else { return }
            timer.invalidate()
            self?.status = "Running"
        }
    }
}
