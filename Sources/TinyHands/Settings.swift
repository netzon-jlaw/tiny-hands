import AppKit
import Carbon.HIToolbox
import Combine

/// Middle Child, Peace Sign, Thumbs Up and Rock On are archived in Resources/Pointers/archive
/// (not bundled) to keep the set small while testing. A saved archived style falls back to Tiny Hand.
enum PointerStyle: String, CaseIterable, Identifiable {
    case classicArrow, tinyHand, highFive, catPaw
    var id: String { rawValue }
    var title: String {
        switch self {
        case .classicArrow: return "Classic"
        case .tinyHand: return "Tiny Hand"
        case .highFive: return "High Five"
        case .catPaw: return "Cat Paw"
        }
    }
}

/// How the rod behind the hand is drawn.
enum StickStyle: String, CaseIterable, Identifiable {
    /// One flat-painted rod with an ink outline, rubber-hose style.
    case solid
    /// The drawn three-section telescoping metal rod (stick.svg).
    case expandable
    var id: String { rawValue }
    var title: String {
        switch self {
        case .solid: return "Solid"
        case .expandable: return "Expandable"
        }
    }
}

/// Preset stick colours. Any other colour can be picked in Settings.
enum StickColor: String, CaseIterable, Identifiable {
    case white, black, red, yellow, teal, pink, blue
    var id: String { rawValue }
    var title: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
    var hex: String {
        switch self {
        case .white: return "#FFFFFF"
        case .black: return "#2A211B"
        case .red: return "#D9473B"
        case .yellow: return "#F2C751"
        case .teal: return "#2EB795"
        case .pink: return "#F29DAD"
        case .blue: return "#4993BE"
        }
    }
}

extension CGColor {
    /// Parses "#RRGGBB".
    static func fromHex(_ hex: String) -> CGColor? {
        let h = hex.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
        guard h.count == 6, let v = UInt32(h, radix: 16) else { return nil }
        return CGColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
                       blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }

    /// "#RRGGBB" in sRGB.
    var hexString: String {
        let c = converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil) ?? self
        let comps = c.components ?? [1, 1, 1]
        let rgb = comps.count >= 3 ? Array(comps[0..<3]) : [comps[0], comps[0], comps[0]]
        let v = rgb.map { Int((max(0, min(1, $0)) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", v[0], v[1], v[2])
    }
}

enum TapLevel: Int, CaseIterable, Identifiable {
    case subtle = 1, polite, lively, loud, unhinged
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .subtle: return "Subtle"
        case .polite: return "Polite"
        case .lively: return "Lively"
        case .loud: return "Loud"
        case .unhinged: return "Unhinged"
        }
    }
    var blurb: String {
        switch self {
        case .subtle: return "A few ink dashes. Board-meeting safe."
        case .polite: return "Dashes and a little dust puff."
        case .lively: return "A real poke: a pow star and flung stars."
        case .loud: return "Hit flash, yellow pow, drops and the shakes."
        case .unhinged: return "Red pow, dizzy stars, spirals, the works."
        }
    }
}

struct Shortcut: Codable, Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32
    var key: String          // display character, e.g. "P"

    var display: String {
        var s = ""
        if carbonModifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if carbonModifiers & UInt32(optionKey) != 0 { s += "⌥" }
        if carbonModifiers & UInt32(shiftKey) != 0 { s += "⇧" }
        if carbonModifiers & UInt32(cmdKey) != 0 { s += "⌘" }
        return s + key
    }

    var cocoaModifiers: NSEvent.ModifierFlags {
        var f: NSEvent.ModifierFlags = []
        if carbonModifiers & UInt32(controlKey) != 0 { f.insert(.control) }
        if carbonModifiers & UInt32(optionKey) != 0 { f.insert(.option) }
        if carbonModifiers & UInt32(shiftKey) != 0 { f.insert(.shift) }
        if carbonModifiers & UInt32(cmdKey) != 0 { f.insert(.command) }
        return f
    }

    static func carbon(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if flags.contains(.control) { m |= UInt32(controlKey) }
        if flags.contains(.option) { m |= UInt32(optionKey) }
        if flags.contains(.shift) { m |= UInt32(shiftKey) }
        if flags.contains(.command) { m |= UInt32(cmdKey) }
        return m
    }

    static let defaultToggle = Shortcut(keyCode: UInt32(kVK_ANSI_P), carbonModifiers: UInt32(controlKey | optionKey), key: "P")
    static let defaultPresentation = Shortcut(keyCode: UInt32(kVK_ANSI_T), carbonModifiers: UInt32(controlKey | optionKey), key: "T")
}

@MainActor
final class Settings: ObservableObject {
    static let shared = Settings()
    private let d = UserDefaults.standard

    @Published var style: PointerStyle { didSet { d.set(style.rawValue, forKey: "style") } }
    @Published var level: TapLevel { didSet { d.set(level.rawValue, forKey: "level") } }
    @Published var escalate: Bool { didSet { d.set(escalate, forKey: "escalate") } }
    @Published var soundOn: Bool { didSet { d.set(soundOn, forKey: "soundOn") } }
    @Published var volume: Double { didSet { d.set(volume, forKey: "volume") } }
    @Published var size: Double { didSet { d.set(size, forKey: "size") } }
    @Published var stickStyle: StickStyle { didSet { d.set(stickStyle.rawValue, forKey: "stickStyle") } }
    /// "#RRGGBB".
    @Published var stickColor: String { didSet { d.set(stickColor, forKey: "stickColor") } }
    @Published var toggleShortcut: Shortcut { didSet { save(toggleShortcut, "toggleShortcut") } }
    @Published var presentationShortcut: Shortcut { didSet { save(presentationShortcut, "presentationShortcut") } }

    var hasLaunchedBefore: Bool {
        get { d.bool(forKey: "hasLaunchedBefore") }
        set { d.set(newValue, forKey: "hasLaunchedBefore") }
    }

    private init() {
        style = PointerStyle(rawValue: d.string(forKey: "style") ?? "") ?? .tinyHand
        level = TapLevel(rawValue: d.integer(forKey: "level")) ?? .lively
        escalate = d.object(forKey: "escalate") as? Bool ?? true
        soundOn = d.object(forKey: "soundOn") as? Bool ?? true
        volume = d.object(forKey: "volume") as? Double ?? 0.6
        size = d.object(forKey: "size") as? Double ?? 1.0
        stickStyle = StickStyle(rawValue: d.string(forKey: "stickStyle") ?? "") ?? .solid
        stickColor = d.string(forKey: "stickColor").flatMap { CGColor.fromHex($0) != nil ? $0 : nil } ?? StickColor.white.hex
        toggleShortcut = Settings.load("toggleShortcut") ?? .defaultToggle
        presentationShortcut = Settings.load("presentationShortcut") ?? .defaultPresentation
    }

    private func save(_ s: Shortcut, _ key: String) {
        if let data = try? JSONEncoder().encode(s) { d.set(data, forKey: key) }
    }

    private static func load(_ key: String) -> Shortcut? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Shortcut.self, from: data)
    }
}
