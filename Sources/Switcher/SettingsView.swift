import SwiftUI

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

    var body: some View {
        NotBuiltYet(what: "Words that are never switched")
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
                        .foregroundStyle(prefs.recording ? .secondary : .primary)
                    Button(prefs.recording ? "Cancel" : "Change…") { prefs.recording.toggle() }
                }
            }
            Text("""
                Retypes the word you just typed in the other layout, or the selected text. \
                Press it again to switch back; that also undoes an automatic fix.
                Use a modifier on its own (⌥), a key with ⌘ ⌃ or ⌥, or F1–F19. Esc cancels.
                """)
                .font(.callout)
                .foregroundStyle(.secondary)
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
