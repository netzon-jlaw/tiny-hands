import AppKit

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let app = AppController.shared
    private let settings = Settings.shared
    private let menu = NSMenu()
    var openSettings: (() -> Void)?

    override init() {
        super.init()
        menu.delegate = self
        menu.autoenablesItems = false
        item.menu = menu
        refreshIcon()
        app.onStateChange = { [weak self] in self?.refreshIcon() }
    }

    func refreshIcon() {
        let name: String
        if app.presentation { name = "hand.tap.fill" }
        else if app.isOn { name = "hand.point.up.left.fill" }
        else { name = "hand.point.up.left" }
        let img = NSImage(systemSymbolName: name, accessibilityDescription: "Tiny Hands")
        img?.isTemplate = true
        item.button?.image = img
        item.button?.toolTip = app.presentation ? "Tiny Hands — Presentation Mode" : (app.isOn ? "Tiny Hands — On" : "Tiny Hands — Off")
    }

    func menuNeedsUpdate(_ menu: NSMenu) { build() }

    private func add(_ title: String, _ action: Selector, key: String = "", mods: NSEvent.ModifierFlags = [],
                     state: Bool = false, to m: NSMenu? = nil, rep: Any? = nil) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.keyEquivalentModifierMask = mods
        i.target = self
        i.state = state ? .on : .off
        i.representedObject = rep
        (m ?? menu).addItem(i)
        return i
    }

    private func build() {
        menu.removeAllItems()
        let ts = settings.toggleShortcut, ps = settings.presentationShortcut

        let header = NSMenuItem(title: app.isOn ? (app.presentation ? "Presenting — clicks are paused" : "Pointer is on") : "Pointer is off", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        _ = add("Show Pointer", #selector(togglePointer), key: ts.key.count == 1 ? ts.key.lowercased() : "", mods: ts.cocoaModifiers, state: app.isOn)
        let pres = add("Presentation Mode", #selector(togglePresentation), key: ps.key.count == 1 ? ps.key.lowercased() : "", mods: ps.cocoaModifiers, state: app.presentation)
        pres.toolTip = "Clicks only tap the pointer — nothing underneath is clicked. Your keyboard stays live. Press \(ps.display) to turn it off."

        menu.addItem(.separator())

        let styleMenu = NSMenu()
        for s in PointerStyle.allCases {
            let i = add(s.title, #selector(pickStyle(_:)), state: settings.style == s, to: styleMenu, rep: s.rawValue)
            i.image = Self.thumbnail(for: s)
        }
        let styleItem = NSMenuItem(title: "Pointer Style", action: nil, keyEquivalent: "")
        styleItem.submenu = styleMenu
        menu.addItem(styleItem)

        let levelMenu = NSMenu()
        for l in TapLevel.allCases {
            let i = add("\(l.rawValue)  \(l.title)", #selector(pickLevel(_:)), state: settings.level == l, to: levelMenu, rep: l.rawValue)
            i.toolTip = l.blurb
        }
        levelMenu.addItem(.separator())
        _ = add("Wilder When Clicking Fast", #selector(toggleEscalate), state: settings.escalate, to: levelMenu)
        let levelItem = NSMenuItem(title: "Tap Mood: \(settings.level.title)", action: nil, keyEquivalent: "")
        levelItem.submenu = levelMenu
        menu.addItem(levelItem)

        menu.addItem(.separator())
        _ = add("Knock Sound", #selector(toggleSound), state: settings.soundOn)
        let vol = NSMenuItem()
        vol.view = VolumeSliderView(value: settings.volume, enabled: settings.soundOn) { [weak self] v in
            self?.settings.volume = v
        }
        menu.addItem(vol)

        menu.addItem(.separator())
        _ = add("Settings…", #selector(showSettings), key: ",", mods: .command)
        _ = add("Launch at Login", #selector(toggleLogin), state: app.launchAtLogin)
        menu.addItem(.separator())
        _ = add("Quit Tiny Hands", #selector(quit), key: "q", mods: .command)
    }

    static func thumbnail(for s: PointerStyle) -> NSImage {
        let art = PointerArt.make(style: s, scale: 0.42, backing: 2)
        let img = NSImage(cgImage: art.image, size: art.size)
        let box = NSSize(width: 22, height: 22)
        return NSImage(size: box, flipped: false) { r in
            let f = min(box.width / art.size.width, box.height / art.size.height)
            let sz = NSSize(width: art.size.width * f, height: art.size.height * f)
            img.draw(in: NSRect(x: (r.width - sz.width) / 2, y: (r.height - sz.height) / 2, width: sz.width, height: sz.height))
            return true
        }
    }

    @objc private func togglePointer() { app.toggle() }
    @objc private func togglePresentation() { app.togglePresentation() }
    @objc private func pickStyle(_ i: NSMenuItem) {
        if let r = i.representedObject as? String, let s = PointerStyle(rawValue: r) { settings.style = s }
    }
    @objc private func pickLevel(_ i: NSMenuItem) {
        if let r = i.representedObject as? Int, let l = TapLevel(rawValue: r) { settings.level = l }
    }
    @objc private func toggleEscalate() { settings.escalate.toggle() }
    @objc private func toggleSound() { settings.soundOn.toggle() }
    @objc private func showSettings() { openSettings?() }
    @objc private func toggleLogin() { app.launchAtLogin.toggle() }
    @objc private func quit() { NSApp.terminate(nil) }
}

final class VolumeSliderView: NSView {
    private let slider: NSSlider
    private let onChange: (Double) -> Void

    init(value: Double, enabled: Bool, onChange: @escaping (Double) -> Void) {
        self.onChange = onChange
        slider = NSSlider(value: value, minValue: 0, maxValue: 1, target: nil, action: nil)
        super.init(frame: NSRect(x: 0, y: 0, width: 240, height: 30))
        let lo = NSImageView(image: NSImage(systemSymbolName: "speaker.fill", accessibilityDescription: "Quiet")!)
        let hi = NSImageView(image: NSImage(systemSymbolName: "speaker.wave.3.fill", accessibilityDescription: "Loud")!)
        lo.contentTintColor = .secondaryLabelColor
        hi.contentTintColor = .secondaryLabelColor
        lo.frame = NSRect(x: 20, y: 7, width: 16, height: 16)
        hi.frame = NSRect(x: 206, y: 7, width: 20, height: 16)
        slider.frame = NSRect(x: 40, y: 5, width: 162, height: 20)
        slider.target = self
        slider.action = #selector(changed)
        slider.isContinuous = true
        slider.isEnabled = enabled
        [lo, slider, hi].forEach(addSubview)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func changed() { onChange(slider.doubleValue) }
}
