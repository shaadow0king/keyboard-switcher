import SwiftUI
import SwitcherCore

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
            SoundsTab()
                .tabItem { Label("Sounds", systemImage: "speaker.wave.2") }
                .tag(SettingsTab.sounds)
        }
        .frame(width: 520, height: 380)
        .onDisappear { prefs.recording = false }
    }
}

enum SettingsTab: Hashable {
    case general, rules, exceptions, hotkeys, sounds
}

struct GeneralTab: View {
    @ObservedObject var prefs: Prefs

    var body: some View {
        Form {
            Toggle("Switch layout automatically", isOn: $prefs.autoSwitch)
        }
        .formStyle(.grouped)
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
                    .width(90)
                TableColumn("Aa") { $rule in Text(rule.caseSensitive ? "Exact case" : "Any case") }
                    .width(80)
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
                Button(isNew ? "Add" : "Save") {
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
        case .whole: "Whole word"
        case .prefix: "Starts with"
        case .contains: "Contains"
        }
    }
}

struct ExceptionsTab: View {
    @ObservedObject var prefs: Prefs

    var body: some View {
        NotBuiltYet(what: "Apps where Switcher stays off")
    }
}

struct HotkeysTab: View {
    @ObservedObject var prefs: Prefs

    var body: some View {
        Form {
            LabeledContent("Convert") {
                HStack {
                    Text(prefs.recording ? "Press a key…" : prefs.hotkey.label)
                        .italic(prefs.recording)
                        .foregroundStyle(.primary)  // LabeledContent dims values; this one must be readable
                    Button(prefs.recording ? "Cancel" : "Change…") { prefs.recording.toggle() }
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

struct SoundsTab: View {
    var body: some View {
        NotBuiltYet(what: "Sounds for switching and fixes")
    }
}

/// Placeholder for a screen that isn't built yet.
struct NotBuiltYet: View {
    let what: String

    var body: some View {
        ContentUnavailableView(what, systemImage: "hammer", description: Text("Not built yet."))
    }
}
