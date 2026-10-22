import AppKit
import SwiftUI

/// Where people send bug reports and ideas. The address lives in Info.plist (MistypeFeedbackEmail),
/// so it changes in one place, without touching code.
enum Feedback {
    static var address: String? {
        (Bundle.main.object(forInfoDictionaryKey: "MistypeFeedbackEmail") as? String).flatMap { $0.isEmpty ? nil : $0 }
    }

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    /// Opens a new email in the user's mail app, with the versions filled in; they see it before sending.
    static func compose() {
        guard let address else { return }
        var mail = URLComponents()
        mail.scheme = "mailto"
        mail.path = address
        mail.queryItems = [
            URLQueryItem(name: "subject", value: String(localized: "Mistype \(version): feedback")),
            URLQueryItem(name: "body", value: "\n\n—\nMistype \(version), macOS \(ProcessInfo.processInfo.operatingSystemVersionString)"),
        ]
        if let url = mail.url { NSWorkspace.shared.open(url) }
    }

    /// For people with no mail app set up: mailto links do nothing for them.
    static func copyAddress() {
        guard let address else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(address, forType: .string)
    }
}

struct AboutTab: View {
    @State private var copied = false
    @ObservedObject var updates = Updates.shared

    var body: some View {
        Form {
            Section {
                LabeledContent("Version") { Text(verbatim: Feedback.version).foregroundStyle(.primary) }
                Text("Free. No subscription. Nothing you type leaves this Mac; Mistype only goes online to check for a new version.")
                    .fixedSize(horizontal: false, vertical: true)
            }
            Section("Updates") {
                if Updates.repo == nil {
                    Text("Updates aren't set up in this build.")
                } else {
                    Toggle("Check for updates automatically", isOn: Binding(
                        get: { updates.checksAutomatically },
                        set: { updates.checksAutomatically = $0 }
                    ))
                    HStack {
                        Button("Check Now") { updates.check() }
                            .disabled(updates.state == .checking)
                        switch updates.state {
                        case .idle: EmptyView()
                        case .checking: ProgressView().controlSize(.small)
                        case .upToDate: Text("You have the latest version.")
                        case .failed: Text("Couldn't check. Try again later.")
                        case .available(let version):
                            Button("Download \(version)") { updates.openReleasePage() }
                        }
                    }
                }
            }
            Section("Feedback and ideas") {
                Text("Found a bug, or missing something? Write to us.")
                    .fixedSize(horizontal: false, vertical: true)
                if let address = Feedback.address {
                    LabeledContent("Email") { Text(verbatim: address).textSelection(.enabled).foregroundStyle(.primary) }
                    HStack {
                        Button("Write an Email") { Feedback.compose() }
                        Button(copied ? String(localized: "Copied") : String(localized: "Copy Address")) {
                            Feedback.copyAddress()
                            copied = true
                        }
                    }
                } else {
                    Text("The feedback address isn't set yet.")
                }
            }
        }
        .formStyle(.grouped)
    }
}
