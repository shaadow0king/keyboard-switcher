import ServiceManagement
import SwiftUI
import MistypeCore

/// The settings window: one tab per settings screen.
struct SettingsView: View {
    @ObservedObject var prefs: Prefs

    var body: some View {
        TabView(selection: $prefs.settingsTab) {
            GeneralTab(prefs: prefs)
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(SettingsTab.general)
            RulesTab(prefs: prefs)
                .tabItem { Label("Rules", systemImage: "text.badge.xmark") }
                .tag(SettingsTab.rules)
            ExceptionsTab(prefs: prefs)
                .tabItem { Label("Apps", systemImage: "app.badge") }
                .tag(SettingsTab.exceptions)
            HotkeysTab(prefs: prefs)
                .tabItem { Label("Hotkeys", systemImage: "command") }
                .tag(SettingsTab.hotkeys)
            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(SettingsTab.about)
        }
        .frame(width: 520, height: 480)
        .onDisappear { prefs.recording = false }
    }
}

enum SettingsTab: Hashable {
    case general, rules, exceptions, hotkeys, about
}

struct GeneralTab: View {
    @ObservedObject var prefs: Prefs
    /// Read from the system each time: the user can also change it in System Settings → Login Items.
    @State private var loginStatus = SMAppService.mainApp.status
    @State private var loginError: String?
    @State private var language = AppLanguage.current
    private let launchedLanguage = AppLanguage.current

    var body: some View {
        Form {
            Toggle("Fix the layout as I type", isOn: $prefs.autoSwitch)
            Toggle("Open Mistype when you log in", isOn: Binding(
                get: { loginStatus == .enabled },
                set: setLaunchAtLogin
            ))
            Picker("Language", selection: $language) {
                Text("Same as macOS").tag(AppLanguage.system)
                Text(verbatim: "English").tag(AppLanguage.english)
                Text(verbatim: "Русский").tag(AppLanguage.russian)
            }
            .onChange(of: language) { _, new in new.apply() }
            if language != launchedLanguage {
                LabeledContent("Mistype needs to restart to change the language.") {
                    Button("Restart") { AppLanguage.relaunch() }
                }
            }
            if loginStatus == .requiresApproval {
                LabeledContent("Allow Mistype in System Settings → General → Login Items.") {
                    Button("Open") { SMAppService.openSystemSettingsLoginItems() }
                }
            }
            if let loginError {
                Label(loginError, systemImage: "exclamationmark.triangle")
                    .symbolRenderingMode(.multicolor)
            }
        }
        .formStyle(.grouped)
        .onAppear { loginStatus = SMAppService.mainApp.status }
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = String(localized: "Couldn't change this: \(error.localizedDescription)")
        }
        loginStatus = SMAppService.mainApp.status
    }
}

struct RulesTab: View {
    @ObservedObject var prefs: Prefs
    @State private var selection = Set<Rule.ID>()
    @State private var editing: Rule?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Words here are never switched to the other layout automatically. The convert hotkey still works on them.")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Table($prefs.rules, selection: $selection) {
                TableColumn("On") { $rule in
                    Toggle("Rule on", isOn: $rule.enabled).labelsHidden()
                }
                .width(28)
                TableColumn("Word") { $rule in
                    Text(rule.text).lineLimit(1).truncationMode(.middle).help(rule.text)
                }
                TableColumn("Match") { $rule in Text(rule.match.label) }
                    .width(min: 90, ideal: 110)
                TableColumn("Aa") { $rule in rule.caseSensitive ? Text("Exact case") : Text("Any case") }
                    .width(min: 80, ideal: 130)
            }
            .contextMenu(forSelectionType: Rule.ID.self) { ids in
                Button("Edit…") { edit(ids) }.disabled(ids.count != 1)
                Button("Remove") { remove(ids) }
            } primaryAction: { ids in
                edit(ids)
            }
            .onDeleteCommand { remove(selection) }
            .overlay {
                if prefs.rules.isEmpty {
                    ContentUnavailableView("No rules yet", systemImage: "text.badge.xmark",
                        description: Text("Add a word that keeps getting switched when it shouldn't, like a name or a code word."))
                }
            }
            HStack(spacing: 0) {
                Button { editing = Rule(text: "") } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add rule")
                Button { remove(selection) } label: { Image(systemName: "minus") }
                    .accessibilityLabel("Remove rule")
                    .disabled(selection.isEmpty)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .sheet(item: $editing) { rule in
            RuleEditor(rule: rule, rules: prefs.rules) { saved in
                if let i = prefs.rules.firstIndex(where: { $0.id == saved.id }) {
                    prefs.rules[i] = saved
                } else {
                    prefs.rules.append(saved)
                }
            }
        }
    }

    private func edit(_ ids: Set<Rule.ID>) {
        guard ids.count == 1, let rule = prefs.rules.first(where: { ids.contains($0.id) }) else { return }
        editing = rule
    }

    private func remove(_ ids: Set<Rule.ID>) {
        prefs.rules.removeAll { ids.contains($0.id) }
        selection.subtract(ids)
    }
}

struct RuleEditor: View {
    @State var rule: Rule
    let rules: [Rule]
    let save: (Rule) -> Void
    @Environment(\.dismiss) private var dismiss

    private var isNew: Bool { !rules.contains { $0.id == rule.id } }
    private var trimmed: String { rule.text.trimmingCharacters(in: .whitespaces) }
    private var duplicate: Bool {
        var candidate = rule
        candidate.text = trimmed
        return rules.hasDuplicate(of: candidate)
    }

    var body: some View {
        Form {
            TextField("Word", text: $rule.text, prompt: Text("in either layout"))
            Picker("Match", selection: $rule.match) {
                ForEach(Rule.Match.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            Toggle("Exact case", isOn: $rule.caseSensitive)
            if duplicate {
                Label("There's already a rule like this.", systemImage: "exclamationmark.triangle")
                    .symbolRenderingMode(.multicolor)
            }
        }
        .formStyle(.grouped)
        .frame(width: 360)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button(isNew ? String(localized: "Add") : String(localized: "Save")) {
                    rule.text = trimmed
                    save(rule)
                    dismiss()
                }
                .disabled(trimmed.isEmpty || duplicate)
            }
        }
    }
}

extension Rule.Match {
    var label: String {
        switch self {
        case .whole: String(localized: "Whole word")
        case .prefix: String(localized: "Starts with")
        case .contains: String(localized: "Contains")
        }
    }
}

struct ExceptionsTab: View {
    @ObservedObject var prefs: Prefs
    @State private var selection = Set<AppException.ID>()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mistype stays off in these apps: no automatic fixes and no hotkey. Handy for terminals, code editors and games.")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            List(prefs.exceptions, selection: $selection) { app in
                HStack {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                        .resizable()
                        .frame(width: 20, height: 20)
                        .accessibilityHidden(true)
                    Text(app.name).lineLimit(1).truncationMode(.middle).help(app.bundleID)
                }
            }
            .onDeleteCommand { remove() }
            .overlay {
                if prefs.exceptions.isEmpty {
                    ContentUnavailableView("No apps yet", systemImage: "app.dashed",
                        description: Text("Add an app where switching gets in the way."))
                }
            }
            HStack(spacing: 0) {
                Button(action: add) { Image(systemName: "plus") }
                    .accessibilityLabel("Add app")
                Button(action: remove) { Image(systemName: "minus") }
                    .accessibilityLabel("Remove app")
                    .disabled(selection.isEmpty)
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    private func add() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        panel.prompt = String(localized: "Add")
        guard panel.runModal() == .OK else { return }
        for app in panel.urls.compactMap(AppException.init(url:))
        where !prefs.exceptions.contains(where: { $0.bundleID == app.bundleID }) {
            prefs.exceptions.append(app)
        }
    }

    private func remove() {
        prefs.exceptions.removeAll { selection.contains($0.id) }
        selection.removeAll()
    }
}

struct HotkeysTab: View {
    @ObservedObject var prefs: Prefs

    var body: some View {
        Form {
            LabeledContent("Convert") {
                HStack {
                    Text(prefs.recording ? String(localized: "Press a key…") : prefs.hotkey.displayLabel)
                        .italic(prefs.recording)
                        .foregroundStyle(.primary)  // LabeledContent dims values; this one must be readable
                    Button(prefs.recording ? String(localized: "Cancel") : String(localized: "Change…")) { prefs.recording.toggle() }
                }
            }
            Text("""
                Retypes the word you just typed in the other layout, or the selected text. \
                Press it again to switch back; that also undoes an automatic fix.
                Use a modifier on its own (⌥), a key with ⌘ ⌃ or ⌥, or F1–F19. Esc cancels.
                """)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
        .formStyle(.grouped)
    }
}
