import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = Settings.shared
    @ObservedObject var app = AppController.shared

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable().frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Make them see it.").font(.title2.weight(.heavy))
                        Text("Turn the pointer on with \(settings.toggleShortcut.display) or from the menu bar. Share your entire screen — not a single window — so everyone sees it.")
                            .font(.callout).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Toggle("Show pointer", isOn: Binding(get: { app.isOn }, set: { app.setOn($0) }))
                Toggle(isOn: Binding(get: { app.presentation }, set: { app.setPresentation($0) })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Presentation Mode")
                        Text("Clicks only tap the pointer — nothing underneath gets clicked. Keyboard stays live. \(settings.presentationShortcut.display) turns it back off.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            Section("Pointer") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                    ForEach(PointerStyle.allCases) { s in
                        StyleCard(style: s, selected: settings.style == s) { settings.style = s }
                    }
                }
                .padding(.vertical, 4)
                HStack {
                    Text("Size")
                    Slider(value: $settings.size, in: 0.6...1.8)
                }
            }

            Section("Tap mood") {
                Picker("Mood", selection: $settings.level) {
                    ForEach(TapLevel.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Text(settings.level.blurb).font(.caption).foregroundStyle(.secondary)
                Toggle("Wilder when you click fast", isOn: $settings.escalate)
            }

            Section("Sound") {
                Toggle("Knock on every tap", isOn: $settings.soundOn)
                HStack {
                    Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                    Slider(value: $settings.volume, in: 0...1)
                    Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
                    Button("Test") { app.testKnock() }
                }
                .disabled(!settings.soundOn)
                Text("The knock plays as system audio. In Zoom tick “Share sound”; in Meet tick “Also share system audio”.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Keyboard shortcuts") {
                LabeledContent("Show / hide pointer") {
                    ShortcutField(shortcut: $settings.toggleShortcut, fallback: .defaultToggle)
                }
                LabeledContent("Presentation Mode") {
                    ShortcutField(shortcut: $settings.presentationShortcut, fallback: .defaultPresentation)
                }
            }

            Section("System") {
                Toggle("Launch at login", isOn: Binding(get: { app.launchAtLogin }, set: { app.launchAtLogin = $0 }))
                HStack {
                    Image(systemName: app.accessibilityGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(app.accessibilityGranted ? .green : .orange)
                    Text(app.accessibilityGranted ? "Accessibility access granted" : "Accessibility access is needed for Presentation Mode")
                    Spacer()
                    if !app.accessibilityGranted {
                        Button("Grant…") {
                            ClickMonitor.requestTrust()
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: min(720, (NSScreen.main?.visibleFrame.height ?? 800) - 60))
    }
}

struct StyleCard: View {
    let style: PointerStyle
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(nsImage: Self.preview(style))
                    .resizable().aspectRatio(contentMode: .fit)
                    .frame(width: 44, height: 44)
                Text(style.title).font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 10).fill(selected ? Color.orange.opacity(0.18) : Color.secondary.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Color.orange : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }

    static func preview(_ s: PointerStyle) -> NSImage {
        let art = PointerArt.make(style: s, scale: 0.9, backing: 2)
        return NSImage(cgImage: art.image, size: art.size)
    }
}

/// Click, then press a key combo (with ⌃, ⌥ or ⌘). Esc cancels, ⌫ resets to default.
struct ShortcutField: NSViewRepresentable {
    @Binding var shortcut: Shortcut
    let fallback: Shortcut

    func makeNSView(context: Context) -> ShortcutRecorderView {
        let v = ShortcutRecorderView()
        v.onChange = { shortcut = $0 }
        v.fallback = fallback
        v.shortcut = shortcut
        return v
    }

    func updateNSView(_ v: ShortcutRecorderView, context: Context) {
        v.shortcut = shortcut
        v.onChange = { shortcut = $0 }
    }
}

final class ShortcutRecorderView: NSButton {
    var onChange: ((Shortcut) -> Void)?
    var fallback: Shortcut = .defaultToggle
    var shortcut: Shortcut = .defaultToggle { didSet { refresh() } }
    private var recording = false { didSet { refresh() } }

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 130, height: 24))
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(begin)
        widthAnchor.constraint(greaterThanOrEqualToConstant: 130).isActive = true
        refresh()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func refresh() {
        title = recording ? "Type shortcut…" : shortcut.display
    }

    override var acceptsFirstResponder: Bool { true }

    @objc private func begin() {
        recording = true
        window?.makeFirstResponder(self)
        MainActor.assumeIsolated { HotKeyCenter.shared.setSuspended(true) }
    }

    private func end() {
        recording = false
        MainActor.assumeIsolated { HotKeyCenter.shared.setSuspended(false) }
    }

    override func resignFirstResponder() -> Bool {
        if recording { end() }
        return super.resignFirstResponder()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if recording { keyDown(with: event); return true }
        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        guard recording else { return super.keyDown(with: event) }
        let mods = event.modifierFlags.intersection([.control, .option, .command, .shift])
        if event.keyCode == 53 { end(); return }                       // Esc
        if event.keyCode == 51 && mods.isEmpty {                       // Delete → default
            shortcut = fallback; onChange?(fallback); end(); return
        }
        guard !mods.intersection([.control, .option, .command]).isEmpty else { NSSound.beep(); return }
        let key = Self.keyName(event)
        let s = Shortcut(keyCode: UInt32(event.keyCode), carbonModifiers: Shortcut.carbon(from: mods), key: key)
        shortcut = s
        onChange?(s)
        end()
    }

    static func keyName(_ e: NSEvent) -> String {
        switch e.keyCode {
        case 49: return "Space"
        case 36: return "↩"
        case 48: return "⇥"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        default:
            let c = e.charactersIgnoringModifiers?.uppercased() ?? "?"
            return c.isEmpty ? "?" : c
        }
    }
}
