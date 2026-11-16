import AppKit
import Carbon.HIToolbox
import Combine

enum PointerStyle: String, CaseIterable, Identifiable {
    case tinyHand, middleChild, peace, thumbsUp, rockOn, highFive, catPaw, classicArrow
    var id: String { rawValue }
    var title: String {
        switch self {
        case .tinyHand: return "Tiny Hand"
        case .catPaw: return "Cat Paw"
        case .middleChild: return "Middle Child"
        case .peace: return "Peace Sign"
        case .thumbsUp: return "Thumbs Up"
        case .rockOn: return "Rock On"
        case .highFive: return "High Five"
        case .classicArrow: return "Classic Arrow"
        }
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
        case .subtle: return "A soft highlight ring. Board-meeting safe."
        case .polite: return "A gentle tap with a ripple."
        case .lively: return "A real poke, with a wobble and impact lines."
        case .loud: return "Telescopic stick and a comic burst."
        case .unhinged: return "Triple jab, confetti, the works."
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
