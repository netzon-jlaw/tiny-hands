import AppKit
import Combine
import ServiceManagement

@MainActor
final class AppController: ObservableObject {
    static let shared = AppController()

    let settings = Settings.shared
    let overlay = OverlayController()
    let clicks = ClickMonitor()
    let knock = KnockPlayer()

    @Published private(set) var isOn = false
    @Published private(set) var presentation = false
    @Published private(set) var accessibilityGranted = ClickMonitor.isTrusted

    var onStateChange: (() -> Void)?

    private var bag = Set<AnyCancellable>()
    private var recentClicks: [CFTimeInterval] = []
    private var trustPoll: Timer?

    private init() {}

    func start() {
        overlay.configure(style: settings.style, scale: settings.size)
        settings.$style.dropFirst().sink { [weak self] s in
            guard let self else { return }
            self.overlay.configure(style: s, scale: self.settings.size)
        }.store(in: &bag)
        settings.$size.dropFirst().sink { [weak self] z in
            guard let self else { return }
            self.overlay.configure(style: self.settings.style, scale: z)
        }.store(in: &bag)
        settings.$toggleShortcut.sink { [weak self] s in
            HotKeyCenter.shared.register(id: 1, shortcut: s) { self?.toggle() }
        }.store(in: &bag)
        settings.$presentationShortcut.sink { [weak self] s in
            HotKeyCenter.shared.register(id: 2, shortcut: s) { self?.togglePresentation() }
        }.store(in: &bag)

        clicks.onMouseDown = { [weak self] in self?.handleClick() }
        clicks.start()

        trustPoll = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let t = ClickMonitor.isTrusted
                if t != self.accessibilityGranted { self.accessibilityGranted = t }
            }
        }
    }

    // MARK: - State

    func toggle() { setOn(!isOn) }

    func setOn(_ on: Bool) {
        guard on != isOn else { return }
        isOn = on
        if on {
            overlay.show()
            CursorHider.hide()
        } else {
            setPresentation(false)
            overlay.hide()
            CursorHider.show()
        }
        onStateChange?()
    }

    func togglePresentation() { setPresentation(!presentation) }

    func setPresentation(_ p: Bool) {
        guard p != presentation else { return }
        if p && !clicks.hasEventTap {
            // Swallowing clicks needs Accessibility permission.
            ClickMonitor.requestTrust()
            NSApp.activate()
            let alert = NSAlert()
            alert.messageText = "Presentation Mode needs Accessibility access"
            alert.informativeText = "Tiny Hands needs permission to hold back your clicks while you present. Enable Tiny Hands in System Settings → Privacy & Security → Accessibility, then try again."
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
            return
        }
        presentation = p
        clicks.swallowClicks = p
        if p { setOn(true) }
        onStateChange?()
    }

    // MARK: - Clicks

    private func handleClick() {
        guard isOn else { return }
        let now = CACurrentMediaTime()
        recentClicks = recentClicks.filter { now - $0 < 1.2 } + [now]
        var level = settings.level.rawValue
        if settings.escalate {
            // The faster you click, the wilder the poke: +1 level per two rapid clicks.
            var streak = 0
            for i in stride(from: recentClicks.count - 1, to: 0, by: -1) {
                if recentClicks[i] - recentClicks[i - 1] < 0.4 { streak += 1 } else { break }
            }
            level = min(5, level + streak / 2)
        }
        overlay.tap(level: level)
        playKnock(level: level)
    }

    func simulateTap(level: Int?) {
        guard isOn else { return }
        let l = max(1, min(5, level ?? settings.level.rawValue))
        overlay.tap(level: l)
        playKnock(level: l)
    }

    /// The knock lands with the visual hit, which trails the click by the lift-and-slam time.
    private func playKnock(level: Int) {
        guard settings.soundOn else { return }
        let delay = TapRecipe.forLevel(level).impact
        let volume = settings.volume
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.knock.knock(level: level, volume: volume)
        }
    }

    func testKnock() {
        knock.knock(level: settings.level.rawValue, volume: settings.volume)
    }

    // MARK: - Launch at login

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("Launch at login change failed: \(error)")
            }
            objectWillChange.send()
        }
    }
}
