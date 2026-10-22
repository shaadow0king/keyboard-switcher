import AppKit
import Combine
import Sparkle

/// In-app updates through Sparkle: it reads appcast.xml (SUFeedURL in Info.plist) once a day, and when there's a
/// newer version it offers to install it; the download is checked against the EdDSA key in Info.plist and the
/// Developer ID signature, then Mistype is replaced in place and relaunched. Its only network requests are the feed
/// and the update itself; Sparkle's system profiling stays off.
final class Updates: ObservableObject {
    static let shared = Updates()

    private let controller: SPUStandardUpdaterController
    @Published private(set) var canCheck = false

    private init() {
        // Snapshots render the settings window offscreen; they must not start checking for updates.
        let snapshot = CommandLine.arguments.contains("--snapshot")
        controller = SPUStandardUpdaterController(startingUpdater: !snapshot, updaterDelegate: nil, userDriverDelegate: nil)
        controller.updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheck)

        // Versions before Sparkle kept their own on/off switch; carry a "no" over once.
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "checkUpdates") as? Bool == false {
            controller.updater.automaticallyChecksForUpdates = false
        }
        defaults.removeObject(forKey: "checkUpdates")
    }

    var checksAutomatically: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set {
            controller.updater.automaticallyChecksForUpdates = newValue
            objectWillChange.send()
        }
    }

    /// Shows Sparkle's window: "You're up to date", or the new version with Install Update.
    func check() {
        NSApp.activate()  // a menu-bar app has to come forward, or the window opens behind others
        controller.updater.checkForUpdates()
    }
}
