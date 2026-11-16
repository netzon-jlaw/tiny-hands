import AppKit
import Darwin

/// Hides the system cursor globally while the pointer overlay is active.
/// A background (LSUIElement) app can only hide the cursor after flipping the
/// window-server connection property "SetsCursorInBackground".
@MainActor
enum CursorHider {
    private typealias ConnFn = @convention(c) () -> Int32
    private typealias SetPropFn = @convention(c) (Int32, Int32, CFString, CFTypeRef) -> Int32

    private typealias VisibleFn = @convention(c) () -> Int32
    /// CGCursorIsVisible is marked unavailable in the SDK but still exported.
    private static let cursorIsVisible: VisibleFn? = {
        guard let h = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_LAZY),
              let sym = dlsym(h, "CGCursorIsVisible") else { return nil }
        return unsafeBitCast(sym, to: VisibleFn.self)
    }()
    private static func isVisible() -> Bool? { cursorIsVisible.map { $0() != 0 } }

    private static var prepared = false
    private static var hideCount = 0
    private static var watchdog: Timer?

    private static func prepare() {
        guard !prepared else { return }
        prepared = true
        let paths = ["/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight",
                     "/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices"]
        for p in paths {
            guard let h = dlopen(p, RTLD_LAZY) else { continue }
            let connSym = dlsym(h, "_CGSDefaultConnection") ?? dlsym(h, "CGSMainConnectionID") ?? dlsym(h, "SLSMainConnectionID")
            let setSym = dlsym(h, "CGSSetConnectionProperty") ?? dlsym(h, "SLSSetConnectionProperty")
            guard let connSym, let setSym else { continue }
            let conn = unsafeBitCast(connSym, to: ConnFn.self)
            let set = unsafeBitCast(setSym, to: SetPropFn.self)
            let cid = conn()
            _ = set(cid, cid, "SetsCursorInBackground" as CFString, kCFBooleanTrue)
            return
        }
    }

    static func hide() {
        prepare()
        hideOnce()
        // Some apps force the cursor visible again (e.g. on app switch). Re-assert.
        watchdog?.invalidate()
        watchdog = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
            MainActor.assumeIsolated {
                if isVisible() == true { hideOnce() }
            }
        }
        RunLoop.main.add(watchdog!, forMode: .common)
    }

    private static func hideOnce() {
        CGDisplayHideCursor(CGMainDisplayID())
        hideCount += 1
    }

    static func show() {
        watchdog?.invalidate()
        watchdog = nil
        while hideCount > 0 {
            CGDisplayShowCursor(CGMainDisplayID())
            hideCount -= 1
        }
        // Belt and braces: make sure it is really back.
        var guardCount = 0
        while isVisible() == false && guardCount < 20 {
            CGDisplayShowCursor(CGMainDisplayID())
            guardCount += 1
        }
    }
}
