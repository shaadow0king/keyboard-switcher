import AppKit
import SwitcherCore

/// Checks the GitHub repository in Info.plist (SwitcherUpdatesRepo, "owner/name") for a newer release.
/// Switcher's only network request: one GET to api.github.com, with nothing about the user or their typing.
/// Installing stays manual: the release page opens and the user downloads the new build.
// shortcut: no in-place install or signed update feed; upgrade to Sparkle once builds are Developer ID-signed.
final class Updates: ObservableObject {
    static let shared = Updates()

    enum State: Equatable { case idle, checking, upToDate, available(String), failed }
    @Published private(set) var state = State.idle
    private(set) var releasePage: URL?

    private let defaults = UserDefaults.standard
    private var timer: Timer?

    static var repo: String? {
        (Bundle.main.object(forInfoDictionaryKey: "SwitcherUpdatesRepo") as? String).flatMap { $0.isEmpty ? nil : $0 }
    }

    var checksAutomatically: Bool {
        get { defaults.object(forKey: "checkUpdates") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "checkUpdates"); objectWillChange.send() }
    }

    /// At launch and every few hours: checks if it's on and the last check was over a day ago.
    func startSchedule() {
        checkIfDue()
        timer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { [weak self] _ in self?.checkIfDue() }
    }

    private func checkIfDue() {
        let last = defaults.object(forKey: "lastUpdateCheck") as? Date ?? .distantPast
        if checksAutomatically, Date().timeIntervalSince(last) > 24 * 3600 { check() }
    }

    func check() {
        guard let repo = Self.repo, state != .checking,
              let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else { return }
        state = .checking
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: request) { data, response, _ in
            let status = (response as? HTTPURLResponse)?.statusCode
            let release = status == 200 ? data.flatMap { try? JSONDecoder().decode(Release.self, from: $0) } : nil
            DispatchQueue.main.async { self.finish(release, noReleasesYet: status == 404) }
        }.resume()
    }

    private func finish(_ release: Release?, noReleasesYet: Bool) {
        defaults.set(Date(), forKey: "lastUpdateCheck")
        if noReleasesYet {  // the repository exists but nothing is published yet
            state = .upToDate
            return
        }
        guard let release, let latest = Version(release.tag_name) else {
            state = .failed
            return
        }
        let current = Version(Feedback.version) ?? Version("0")!
        releasePage = URL(string: release.html_url)
        state = latest > current ? .available(latest.description) : .upToDate
    }

    func openReleasePage() {
        if let releasePage { NSWorkspace.shared.open(releasePage) }
    }

    private struct Release: Decodable {
        let tag_name: String
        let html_url: String
    }
}
