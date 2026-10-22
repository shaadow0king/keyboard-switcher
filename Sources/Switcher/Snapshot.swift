import AppKit
import SwiftUI
import SwitcherCore

/// `Switcher --snapshot <dir>`: renders each settings screen to PNG offscreen, for visual checks.
/// Uses its own throwaway defaults and never starts the key tap.
enum Snapshot {
    static func run(to dir: URL) {
        let suite = "local.switcher.snapshot"
        UserDefaults().removePersistentDomain(forName: suite)
        defer { UserDefaults().removePersistentDomain(forName: suite) }
        let prefs = Prefs(defaults: UserDefaults(suiteName: suite)!)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        func shot(_ name: String, _ tab: SettingsTab) {
            prefs.settingsTab = tab
            for (suffix, look) in [("", NSAppearance.Name.aqua), ("-dark", .darkAqua)] {
                save(SettingsView(prefs: prefs), name + suffix, look, dir)
            }
        }

        let app = AppDelegate()
        for (name, granted) in [("S02-permission-waiting", false), ("S02-permission-granted", true)] {
            app.hasPermission = granted
            for (suffix, look) in [("", NSAppearance.Name.aqua), ("-dark", .darkAqua)] {
                save(PermissionView(app: app), name + suffix, look, dir)
            }
        }
        shot("S03-general", .general)
        shot("S07-hotkeys", .hotkeys)
        shot("S04-rules-empty", .rules)
        prefs.rules = [
            Rule(text: "ghbdtn"),
            Rule(text: "http", match: .prefix),
            Rule(text: "API", caseSensitive: true, enabled: false),
            Rule(text: String(repeating: "verylongword", count: 5)),  // 60 characters
        ]
        shot("S04-rules-filled", .rules)
    }

    private static func save(_ view: some View, _ name: String, _ look: NSAppearance.Name, _ dir: URL) {
        // cacheDisplay doesn't draw the window background, so the view carries its own.
        let host = NSHostingView(rootView: view.background(Color(nsColor: .windowBackgroundColor)))
        host.appearance = NSAppearance(named: look)
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        let window = NSWindow(contentRect: host.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: look)
        window.contentView = host
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))  // let SwiftUI lay out and draw
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: dir.appendingPathComponent(name + ".png"))
    }
}
