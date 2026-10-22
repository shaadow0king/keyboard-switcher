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

func showSettings() {
    AppWindow.settings.show(title: String(localized: "Switcher Settings")) { SettingsView(prefs: .shared) }
}

struct MenuView: View {
    // Passed in: MenuBarExtra content doesn't receive the delegate as an environment object.
    @ObservedObject var app: AppDelegate
    @ObservedObject var prefs: Prefs

    var body: some View {
        Text(app.status)
        if !app.hasPermission {
            Button("Grant Permission…") { PermissionWindow.show(app) }
        }
        Text("Convert: \(prefs.hotkey.displayLabel)")
        Button("Change Hotkey…") {
            prefs.settingsTab = .hotkeys
            prefs.recording = true
            showSettings()
        }
        Divider()
        Toggle("Switch layout automatically", isOn: $prefs.autoSwitch)
        Button("Settings…") { showSettings() }
        .keyboardShortcut(",")
        Divider()
        Button("Quit Switcher") { NSApp.terminate(nil) }
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
                // Let the "Switcher is on" line show for a moment, then get out of the way.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { PermissionWindow.close() }
            } else if watchdog != nil {
                PermissionWindow.show(self)  // revoked while running
            }
        }
        let new = if !running {
            String(localized: "Needs Accessibility permission")
        } else if let owner = Focus.secureInputOwner() {
            String(localized: "Paused: \(owner) has secure keyboard input on")
        } else {
            String(localized: "Running")
        }
        if status != new { status = new }
    }
}
