import ApplicationServices
import Carbon.HIToolbox
import SwiftUI

@main
struct MistypeApp: App {
    @NSApplicationDelegateAdaptor private var app: AppDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuView(app: app, prefs: .shared)
        } label: {
            MenuBarLabel(app: app)
        }
    }
}

/// The current layout as RU / EN in the menu bar; the keyboard icon for any other layout.
struct MenuBarLabel: View {
    @ObservedObject var app: AppDelegate

    var body: some View {
        if let layout = app.layout {
            Text(verbatim: layout)
                .accessibilityLabel(Text("Mistype, layout \(layout)"))
        } else {
            Image(systemName: "keyboard")
                .accessibilityLabel(Text(verbatim: "Mistype"))
        }
    }
}

func showSettings() {
    AppWindow.settings.show(title: String(localized: "Mistype Settings")) { SettingsView(prefs: .shared) }
}

struct MenuView: View {
    // Passed in: MenuBarExtra content doesn't receive the delegate as an environment object.
    @ObservedObject var app: AppDelegate
    @ObservedObject var prefs: Prefs
    @ObservedObject var updates = Updates.shared

    var body: some View {
        Text(app.status)
        if !app.hasPermission {
            Button("Give Permission…") { PermissionWindow.show(app) }
        }
        Text("Convert key: \(prefs.hotkey.displayLabel)")
        Button("Change Hotkey…") {
            prefs.settingsTab = .hotkeys
            prefs.recording = true
            showSettings()
        }
        Divider()
        Toggle("Fix the layout automatically as I type", isOn: $prefs.autoSwitch)
        Button("Check for Updates…") { updates.check() }
            .disabled(!updates.canCheck)
        Button("Settings…") { showSettings() }
        Button("Feedback and Ideas…") {
            prefs.settingsTab = .about
            showSettings()
        }
        .keyboardShortcut(",")
        Divider()
        Button("Quit Mistype") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published var status = String(localized: "Starting…")
    @Published var hasPermission = false
    /// "RU" / "EN", or nil for any other layout.
    @Published var layout = Layouts.currentCode()
    private var layoutObserver: NSObjectProtocol?
    private var watchdog: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        layoutObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.layout = Layouts.currentCode()
        }
        _ = Updates.shared  // starts Sparkle's daily check
        checkPermission()
        // Our own window instead of the bare system prompt: it says why, and closes when granted.
        if !hasPermission { PermissionWindow.show(self) }
        // Also stops the tap within half a second if permission is revoked while running.
        watchdog = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkPermission()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        KeyTap.shared.stop()
    }

    /// Checks in a row that found no permission; the guide window waits for a few, so one slow answer
    /// from a hung app doesn't pop it up. The tap itself is removed on the first one.
    private var misses = 0

    private func checkPermission() {
        let granted = Focus.accessibilityWorks()
        misses = granted ? 0 : misses + 1
        if !granted, KeyTap.shared.isRunning { log.notice("permission check failed: removing the tap") }
        let running = granted && KeyTap.shared.start()
        if !running { KeyTap.shared.stop() }
        if running != hasPermission, running || misses >= 3 || watchdog == nil {
            hasPermission = running
            if running {
                // Let the "Mistype is on" line show for a moment, then get out of the way.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { PermissionWindow.close() }
            } else if watchdog != nil {
                PermissionWindow.show(self)  // revoked while running
            }
        }
        let new = if !running {
            String(localized: "Needs permission to see typing")
        } else if let owner = Focus.secureInputOwner() {
            String(localized: "Paused while \(owner) protects your typing")
        } else {
            String(localized: "On")
        }
        if status != new { status = new }
    }
}
