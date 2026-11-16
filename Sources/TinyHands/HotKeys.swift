import Carbon.HIToolbox
import Foundation

/// Global hotkeys via Carbon's RegisterEventHotKey — needs no special permission.
@MainActor
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var handlers: [UInt32: () -> Void] = [:]
    private var shortcuts: [UInt32: Shortcut] = [:]
    private var suspended = false

    private init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hk = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hk)
            let id = hk.id
            DispatchQueue.main.async { MainActor.assumeIsolated { HotKeyCenter.shared.handlers[id]?() } }
            return noErr
        }, 1, &spec, nil, nil)
    }

    func register(id: UInt32, shortcut: Shortcut, handler: @escaping () -> Void) {
        handlers[id] = handler
        shortcuts[id] = shortcut
        unregister(id)
        if !suspended { activate(id) }
    }

    private func activate(_ id: UInt32) {
        guard let s = shortcuts[id] else { return }
        var ref: EventHotKeyRef?
        let hkid = EventHotKeyID(signature: OSType(0x544E_4844), id: id) // 'TNHD'
        if RegisterEventHotKey(s.keyCode, s.carbonModifiers, hkid, GetApplicationEventTarget(), 0, &ref) == noErr, let ref {
            refs[id] = ref
        }
    }

    private func unregister(_ id: UInt32) {
        if let r = refs[id] { UnregisterEventHotKey(r); refs[id] = nil }
    }

    /// Used while a shortcut recorder is focused so the keys can be captured.
    func setSuspended(_ s: Bool) {
        guard s != suspended else { return }
        suspended = s
        for id in shortcuts.keys { s ? unregister(id) : activate(id) }
    }
}
