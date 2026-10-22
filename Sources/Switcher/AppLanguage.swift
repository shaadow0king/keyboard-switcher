import AppKit

/// The interface language: follow macOS, or force English or Russian for Switcher only.
/// Stored the standard way, as AppleLanguages in Switcher's own defaults; it takes effect on the next launch.
enum AppLanguage: Hashable {
    case system, english, russian

    private static let key = "AppleLanguages"

    static var current: AppLanguage {
        // Only Switcher's own domain: UserDefaults.standard would also return the system-wide list.
        guard let id = Bundle.main.bundleIdentifier,
              let langs = UserDefaults.standard.persistentDomain(forName: id)?[key] as? [String],
              let first = langs.first else { return .system }
        return first.hasPrefix("ru") ? .russian : first.hasPrefix("en") ? .english : .system
    }

    func apply() {
        switch self {
        case .system: UserDefaults.standard.removeObject(forKey: Self.key)
        case .english: UserDefaults.standard.set(["en"], forKey: Self.key)
        case .russian: UserDefaults.standard.set(["ru"], forKey: Self.key)
        }
    }

    /// Quits and opens Switcher again. The new copy starts after this one has quit,
    /// so two key taps never run at once.
    static func relaunch() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 0.5; /usr/bin/open \"$0\"", Bundle.main.bundlePath]
        try? task.run()
        NSApp.terminate(nil)
    }
}
