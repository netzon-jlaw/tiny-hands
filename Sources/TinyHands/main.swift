import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBar: MenuBarController?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppController.shared.start()
        let mb = MenuBarController()
        mb.openSettings = { [weak self] in self?.showSettings() }
        menuBar = mb

        if !Settings.shared.hasLaunchedBefore {
            Settings.shared.hasLaunchedBefore = true
            showSettings()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    /// Automation: tinyhands://on | off | toggle | present | unpresent | tap?level=1-5 | settings
    func application(_ application: NSApplication, open urls: [URL]) {
        let app = AppController.shared
        for url in urls where url.scheme == "tinyhands" {
            switch url.host ?? "" {
            case "on": app.setOn(true)
            case "off": app.setOn(false)
            case "toggle": app.toggle()
            case "present": app.setPresentation(true)
            case "unpresent": app.setPresentation(false)
            case "settings": showSettings()
            case "tap":
                let lvl = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first { $0.name == "level" }?.value.flatMap(Int.init)
                app.simulateTap(level: lvl)
            default: break
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        CursorHider.show()
    }

    func showSettings() {
        if settingsWindow == nil {
            let host = NSHostingController(rootView: SettingsView())
            let w = NSWindow(contentViewController: host)
            w.title = "Tiny Hands"
            w.styleMask = [.titled, .closable, .miniaturizable]
            w.isReleasedWhenClosed = false
            w.center()
            settingsWindow = w
        }
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    withExtendedLifetime(delegate) { app.run() }
}
