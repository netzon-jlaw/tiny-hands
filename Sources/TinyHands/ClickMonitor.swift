import AppKit
import ApplicationServices

/// Watches mouse clicks system-wide. With Accessibility permission it uses an
/// active CGEventTap, which also lets Presentation Mode swallow clicks.
/// Without permission it falls back to a passive NSEvent global monitor.
@MainActor
final class ClickMonitor {
    var onMouseDown: (() -> Void)?
    /// When true, mouse button events never reach the apps underneath.
    var swallowClicks = false

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var permissionPoll: Timer?

    var hasEventTap: Bool { tap != nil }

    static var isTrusted: Bool { AXIsProcessTrusted() }

    static func requestTrust() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }

    func start() {
        if !installTap() {
            installFallback()
            // Upgrade to the event tap as soon as permission is granted.
            permissionPoll = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
                MainActor.assumeIsolated {
                    guard let self, ClickMonitor.isTrusted else { return }
                    if self.installTap() {
                        self.removeFallback()
                        t.invalidate()
                    }
                }
            }
        }
    }

    private func installTap() -> Bool {
        guard ClickMonitor.isTrusted, tap == nil else { return tap != nil }
        let types: [CGEventType] = [.leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
                                    .otherMouseDown, .otherMouseUp, .leftMouseDragged, .rightMouseDragged,
                                    .otherMouseDragged]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                          options: .defaultTap, eventsOfInterest: mask,
                                          callback: clickTapCallback, userInfo: refcon) else { return false }
        self.tap = tap
        source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    private func installFallback() {
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            MainActor.assumeIsolated { self?.onMouseDown?() }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] e in
            MainActor.assumeIsolated { self?.onMouseDown?() }
            return e
        }
    }

    private func removeFallback() {
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
        if let m = localMonitor { NSEvent.removeMonitor(m) }
        globalMonitor = nil
        localMonitor = nil
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            onMouseDown?()
            return swallowClicks ? nil : Unmanaged.passUnretained(event)
        default:
            return swallowClicks ? nil : Unmanaged.passUnretained(event)
        }
    }
}

private func clickTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
                              refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let monitor = Unmanaged<ClickMonitor>.fromOpaque(refcon).takeUnretainedValue()
    return MainActor.assumeIsolated { monitor.handle(type: type, event: event) }
}
