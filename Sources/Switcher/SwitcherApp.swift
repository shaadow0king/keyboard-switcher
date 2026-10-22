import ApplicationServices
import Carbon.HIToolbox
import SwiftUI

@main
struct SwitcherApp: App {
    @NSApplicationDelegateAdaptor private var app: AppDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuView(app: app, prefs: .shared)
        } label: {
            MenuBarLabel(app: app)
        }
        Window("Switcher Settings", id: "settings") {
            SettingsView(prefs: .shared)
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
    }
}

/// The current layout as RU / EN in the menu bar; the keyboard icon for any other layout.
struct MenuBarLabel: View {
    @ObservedObject var app: AppDelegate

    var body: some View {
        if let layout = app.layout {
            Text(verbatim: layout)
                .accessibilityLabel(Text("Switcher, layout \(layout)"))
        } else {
            Image(systemName: "keyboard")
                .accessibilityLabel(Text(verbatim: "Switcher"))
        }
    }
}

struct MenuView: View {
    // Passed in: MenuBarExtra content doesn't receive the delegate as an environment object.
    @ObservedObject var app: AppDelegate
    @ObservedObject var prefs: Prefs
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(app.status)
        Text("Convert: \(prefs.hotkey.displayLabel)")
        Button("Change Hotkey…") {
            prefs.settingsTab = .hotkeys
            prefs.recording = true
            openWindow(id: "settings")
            NSApp.activate()
        }
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

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published var status = String(localized: "Starting…")
    /// "RU" / "EN", or nil for any other layout.
    @Published var layout = Layouts.currentCode()
    private var layoutObserver: NSObjectProtocol?
    private var watchdog: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let i = CommandLine.arguments.firstIndex(of: "--snapshot"), i + 1 < CommandLine.arguments.count {
            Snapshot.run(to: URL(fileURLWithPath: CommandLine.arguments[i + 1]))
            exit(0)
        }
        layoutObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.layout = Layouts.currentCode()
        }
        // Ask once; after that the watchdog starts the tap when permission arrives.
        AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        checkPermission()
        // Also stops the tap within half a second if permission is revoked while running.
        watchdog = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkPermission()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        KeyTap.shared.stop()
    }

    private func checkPermission() {
        let running = AXIsProcessTrusted() && KeyTap.shared.start()
        if !running { KeyTap.shared.stop() }
        let new = running ? String(localized: "Running") : String(localized: "Needs Accessibility permission")
        if status != new { status = new }
    }
}
