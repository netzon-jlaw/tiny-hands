import AppKit
import QuartzCore

/// Transparent, click-through window covering one screen. It is visible to
/// screen capture, so the pointer shows up in shares and recordings.
final class OverlayWindow: NSWindow {
    let root = CALayer()

    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        setFrame(screen.frame, display: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isReleasedWhenClosed = false
        sharingType = .readOnly
        animationBehavior = .none
        let v = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
        v.wantsLayer = true
        v.layer = root
        root.masksToBounds = false
        contentView = v
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// The aged 1930s palette for the stick and the tap effects. Lines are dark ink on
/// light screens and cream on dark ones; painted shapes (puffs, stars) are always
/// cream with a sepia shade and an ink outline, like cel paint.
struct Ink {
    let dark: Bool
    static var current: Ink {
        Ink(dark: NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua)
    }
    /// #1B1410
    static let ink = CGColor(srgbRed: 0x1B / 255.0, green: 0x14 / 255.0, blue: 0x10 / 255.0, alpha: 1)
    /// #F3E6C4
    static let cream = CGColor(srgbRed: 0xF3 / 255.0, green: 0xE6 / 255.0, blue: 0xC4 / 255.0, alpha: 1)
    /// #D2B98C
    static let sepia = CGColor(srgbRed: 0xD2 / 255.0, green: 0xB9 / 255.0, blue: 0x8C / 255.0, alpha: 1)

    /// Pale-yellow accent paint, #F6D27A.
    static let yellow = CGColor(srgbRed: 0xF6 / 255.0, green: 0xD2 / 255.0, blue: 0x7A / 255.0, alpha: 1)
    /// Faded-red accent paint, #C2493B.
    static let red = CGColor(srgbRed: 0xC2 / 255.0, green: 0x49 / 255.0, blue: 0x3B / 255.0, alpha: 1)

    /// Line work (rings, plinks, shake lines, streaks): ink, or cream on a dark screen.
    var marks: CGColor { dark ? Ink.cream : Ink.ink }
    /// Outline under painted shapes.
    var outline: CGColor { Ink.ink }
    var paint: CGColor { Ink.cream }
    var shade: CGColor { Ink.sepia }
    /// Fallback gradient rod (used only when Resources/Pointers/stick.svg is missing).
    var stick: CGColor {
        dark ? CGColor(srgbRed: 0.58, green: 0.58, blue: 0.58, alpha: 1)
             : CGColor(srgbRed: 0.02, green: 0.02, blue: 0.03, alpha: 1)
    }
}

/// The pointer layer tree: pointer (at mouse) → lean (the rod trailing behind a fast move,
/// pivot = fingertip) → sway (idle rock, pivot = fingertip) → body (tilt, anchor at tip)
/// → stick (rod) + hand.
/// The stick is one long rod continuing the hand's axis out of the cuff: the drawn
/// telescoping rod from stick.svg when it is bundled, otherwise a gradient that fades out.
final class PointerLayers {
    let pointer = CALayer()
    /// Zero-size layer at the fingertip. PointerMotion's swing rotates it.
    let lean = CALayer()
    /// Zero-size layer at the fingertip. The idle sway rotates it, so the tip never
    /// leaves the mouse point.
    let sway = CALayer()
    let body = CALayer()
    let hand = CALayer()
    let stick = CALayer()
    let rod = CAGradientLayer()
    /// The drawn rod (Resources/Pointers/stick.svg), when bundled.
    let rodArt = CALayer()
    private let rodFade = CAGradientLayer()
    /// The solid rod: flat paint, a cel shade down one side, a shine stripe and an ink outline.
    let rodSolid = CALayer()
    private let solidFill = CAShapeLayer()
    private let solidShade = CAShapeLayer()
    private let solidShine = CAShapeLayer()
    private let solidOutline = CAShapeLayer()
    private let solidFade = CAGradientLayer()
    var art: PointerArt?
    var ink = Ink(dark: false)
    private var stickColor = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
    private var frameIndex = 0
    /// Which roll drawing is showing (0 = upright).
    private var rollStep = 0

    /// Line boil + film grain: step to the next pre-rendered film frame.
    func advanceFrame() {
        guard let art, art.frames.count > 1 else { return }
        frameIndex = (frameIndex + 1) % art.frames.count
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        showFrame(art)
        CATransaction.commit()
    }

    private func showFrame(_ art: PointerArt) {
        let film = art.film(roll: rollStep)
        hand.contents = film[frameIndex % film.count]
    }

    /// Shows the hand turned to `rollStep` and the whole pointer leaning by `swing` radians
    /// about the fingertip. Call inside a transaction with actions disabled.
    func setMotion(rollStep step: Int, swing: CGFloat) {
        lean.transform = CATransform3DMakeRotation(swing, 0, 0, 1)
        guard let art, step != rollStep else { return }
        rollStep = step
        showFrame(art)
        // The cuff shifts a little as the hand turns; the rod follows it.
        stick.position = art.wrist(roll: step)
    }

    init() {
        pointer.bounds = .zero
        lean.bounds = .zero
        lean.position = .zero
        sway.bounds = .zero
        sway.position = .zero
        pointer.addSublayer(lean)
        lean.addSublayer(sway)
        sway.addSublayer(body)
        body.addSublayer(stick)
        body.addSublayer(hand)
        // The glove casts no drop shadow; it is flat cel art.
        hand.shadowOpacity = 0
        stick.addSublayer(rod)
        stick.addSublayer(rodArt)
        stick.addSublayer(rodSolid)
        rodArt.isHidden = true
        rodSolid.isHidden = true
        [solidFill, solidShade, solidShine, solidOutline].forEach(rodSolid.addSublayer)
        rodSolid.mask = solidFade
    }

    private static let stickSVG: NSImage? = {
        guard let url = Bundle.main.url(forResource: "stick", withExtension: "svg", subdirectory: "Pointers"),
              let img = NSImage(contentsOf: url), img.size.width > 0, img.size.height > 0 else { return nil }
        return img
    }()

    /// Rasterises stick.svg to `size` points at the screen's backing scale.
    private static func renderStick(_ img: NSImage, size: CGSize, backing: CGFloat) -> CGImage? {
        let w = Int(ceil(size.width * backing)), h = Int(ceil(size.height * backing))
        guard w > 0, h > 0,
              let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        img.draw(in: NSRect(x: 0, y: 0, width: w, height: h))
        NSGraphicsContext.restoreGraphicsState()
        return ctx.makeImage()
    }

    /// Recolours the grey metal rod: the colour fills the mid-tones and the specular
    /// highlights stay white. White leaves the rod as drawn.
    private static func tint(_ img: CGImage, _ color: CGColor) -> CGImage {
        let c = color.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil)?.components ?? [1, 1, 1, 1]
        let tr = Float(c[0]), tg = Float(c.count > 2 ? c[1] : c[0]), tb = Float(c.count > 2 ? c[2] : c[0])
        if tr > 0.99 && tg > 0.99 && tb > 0.99 { return img }
        let w = img.width, h = img.height
        var d = [UInt8](repeating: 0, count: w * h * 4)
        let ctx = CGContext(data: &d, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        for i in stride(from: 0, to: d.count, by: 4) {
            let a = Float(d[i + 3]) / 255
            guard a > 0 else { continue }
            let l = (0.299 * Float(d[i]) + 0.587 * Float(d[i + 1]) + 0.114 * Float(d[i + 2])) / 255 / a
            let hi = pow(min(1, l), 4)
            func mix(_ t: Float) -> UInt8 { UInt8(max(0, min(1, t * min(1, l * 1.25) * (1 - hi) + hi)) * a * 255) }
            d[i] = mix(tr); d[i + 1] = mix(tg); d[i + 2] = mix(tb)
        }
        return ctx.makeImage() ?? img
    }

    /// A slightly darker, warmer cel shade of `color` (sepia-leaning, never grey).
    static func shade(of color: CGColor, by k: CGFloat = 1) -> CGColor {
        let (r, g, b) = rgb(color)
        // Multiply by the sepia shade used on the painted tap effects.
        return CGColor(srgbRed: r * 0.82 * k, green: g * 0.73 * k, blue: b * 0.6 * k, alpha: 1)
    }

    static func rgb(_ color: CGColor) -> (CGFloat, CGFloat, CGFloat) {
        let c = color.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil)?.components ?? [1, 1, 1, 1]
        return c.count > 2 ? (c[0], c[1], c[2]) : (c[0], c[0], c[0])
    }

    static func luminance(_ color: CGColor) -> CGFloat {
        let (r, g, b) = rgb(color)
        return 0.299 * r + 0.587 * g + 0.114 * b
    }

    func apply(_ art: PointerArt, contentsScale: CGFloat, ink: Ink, stickStyle: StickStyle, stickColor: CGColor) {
        self.art = art
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        body.bounds = CGRect(origin: .zero, size: art.size)
        body.anchorPoint = CGPoint(x: art.hotspot.x / art.size.width, y: art.hotspot.y / art.size.height)
        body.position = .zero
        body.transform = CATransform3DMakeRotation(art.tilt, 0, 0, 1)
        body.removeAnimation(forKey: "tap")
        hand.removeAnimation(forKey: "squash")
        hand.transform = CATransform3DIdentity
        hand.frame = body.bounds
        rollStep = 0
        lean.transform = CATransform3DIdentity
        hand.contents = art.image
        hand.contentsScale = contentsScale
        hand.contentsGravity = .resize

        // A ~59 pt glove on a ~330 pt rod, hanging from the wrist along the hand's axis.
        let len = art.size.height * 5.6
        stick.isHidden = !art.hasStick
        stick.frame = CGRect(x: art.wrist.x, y: art.wrist.y, width: 0, height: 0)
        rodSolid.isHidden = true

        if art.hasStick && stickStyle == .solid {
            // A plain painted dowel, thinner than the metal rod, in flat cel paint.
            let w = max(5, art.size.height * 0.2)
            let ow = max(1.2, w * 0.12)
            let top = w * 0.6           // tucks a little way up under the cuff
            let rect = CGRect(x: -w / 2, y: top - len, width: w, height: len)
            rod.isHidden = true
            rodArt.isHidden = true
            rodSolid.isHidden = false
            rodSolid.frame = CGRect(x: 0, y: 0, width: 0, height: 0)
            let body = CGPath(roundedRect: rect, cornerWidth: w / 2, cornerHeight: w / 2, transform: nil)
            solidOutline.path = body
            solidOutline.fillColor = nil
            // The same even ink line as the hands; a near-black stick on a dark desktop
            // gets a cream outline so it still shows.
            // (Set in setInk, which also runs when the appearance changes.)
            self.stickColor = stickColor
            solidOutline.lineWidth = ow
            solidFill.path = body
            solidFill.fillColor = stickColor
            // Cel shade: a band down the right (shadow) side, inside the outline.
            let shadeRect = CGRect(x: w * 0.18, y: rect.minY, width: w * 0.26, height: len - w * 0.2)
            solidShade.path = CGPath(roundedRect: shadeRect, cornerWidth: w * 0.13, cornerHeight: w * 0.13, transform: nil)
            solidShade.fillColor = Self.shade(of: stickColor)
            // Shine: a short white stroke near the lit (left) edge, broken like a cel highlight.
            let shine = CGMutablePath()
            let sx = -w * 0.2
            shine.move(to: CGPoint(x: sx, y: top - w * 1.1))
            shine.addLine(to: CGPoint(x: sx, y: top - len * 0.34))
            shine.move(to: CGPoint(x: sx, y: top - len * 0.34 - w * 0.9))
            shine.addLine(to: CGPoint(x: sx, y: top - len * 0.34 - w * 1.6))
            solidShine.path = shine
            solidShine.strokeColor = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.85)
            solidShine.fillColor = nil
            solidShine.lineWidth = max(1, w * 0.16)
            solidShine.lineCap = .round
            [solidFill, solidShade, solidShine, solidOutline].forEach { $0.contentsScale = contentsScale }
            // Fade the far end so the rod never stops dead in the middle of the screen.
            solidFade.frame = CGRect(x: rect.minX - ow, y: rect.minY, width: rect.width + ow * 2, height: rect.height + ow)
            solidFade.startPoint = CGPoint(x: 0.5, y: 1)
            solidFade.endPoint = CGPoint(x: 0.5, y: 0)
            solidFade.colors = [CGColor.black, CGColor.black, CGColor.clear]
            solidFade.locations = [0, 0.72, 1]
            CATransaction.commit()
            setInk(ink)
            return
        }

        if art.hasStick, let svg = Self.stickSVG {
            let w = len * svg.size.width / svg.size.height
            if let raw = Self.renderStick(svg, size: CGSize(width: w, height: len), backing: contentsScale) {
                let img = Self.tint(raw, stickColor)
                rod.isHidden = true
                rodArt.isHidden = false
                rodArt.anchorPoint = CGPoint(x: 0.5, y: 1)
                rodArt.bounds = CGRect(x: 0, y: 0, width: w, height: len)
                // The cuff end tucks a little way up under the cuff.
                rodArt.position = CGPoint(x: 0, y: w * 0.5)
                rodArt.contents = img
                rodArt.contentsScale = contentsScale
                rodArt.contentsGravity = .resize
                // Fade the far end so the rod never stops dead in the middle of the screen.
                rodFade.frame = rodArt.bounds
                rodFade.startPoint = CGPoint(x: 0.5, y: 1)
                rodFade.endPoint = CGPoint(x: 0.5, y: 0)
                rodFade.colors = [CGColor.black, CGColor.black, CGColor.clear]
                rodFade.locations = [0, 0.72, 1]
                rodArt.mask = rodFade
                CATransaction.commit()
                setInk(ink)
                return
            }
        }
        rodArt.isHidden = true
        rod.isHidden = false
        let w = max(4, art.size.height * 0.29)
        rod.anchorPoint = CGPoint(x: 0.5, y: 1)
        // Start a little inside the cuff so the rod tucks under it.
        rod.bounds = CGRect(x: 0, y: 0, width: w, height: len)
        rod.position = CGPoint(x: 0, y: w * 0.6)
        rod.cornerRadius = w * 0.18
        rod.contentsScale = contentsScale
        CATransaction.commit()
        setInk(ink)
    }

    func setInk(_ ink: Ink) {
        self.ink = ink
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        solidOutline.strokeColor = Self.luminance(stickColor) < 0.25 && ink.dark ? Ink.cream : Ink.ink
        let c = ink.stick
        // Gradient runs from the wrist (top, y = 1) to the far end (bottom, y = 0).
        rod.startPoint = CGPoint(x: 0.5, y: 1)
        rod.endPoint = CGPoint(x: 0.5, y: 0)
        rod.colors = [c, c, c.copy(alpha: 0.55)!, c.copy(alpha: 0)!]
        rod.locations = [0, 0.18, 0.55, 1]
        CATransaction.commit()
    }

    /// Hand-held idle drift: a slow, tiny rock of the whole hand and rod about the
    /// fingertip (about ±0.6°). The pivot is the tip, so the hotspot stays on the mouse.
    func setIdleSway(_ on: Bool) {
        sway.removeAnimation(forKey: "sway")
        guard on else { return }
        // Two slow sines that both loop over 7.8 s (3 and 5 cycles), so the loop is seamless.
        let loop = 7.8, n = 96
        let a = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        a.values = (0...n).map { i -> Double in
            let t = Double(i) / Double(n) * loop
            return 0.0072 * sin(2 * .pi * t / 2.6) + 0.0034 * sin(2 * .pi * t / 1.56 + 1.3)
        }
        a.duration = loop
        a.repeatCount = .infinity
        a.timeOffset = Double.random(in: 0..<loop)
        a.isRemovedOnCompletion = false
        sway.add(a, forKey: "sway")
    }
}

// MARK: - Tap recipes and effects (pure geometry; no layers)
//
// Modelled on the "Mr Tiny Hand" toy videos (YouTube Shorts + TikTok @mr.tiny.hand,
// 30/60 fps, frame by frame). The toy rests on the glass, then the operator's wrist
// flicks it up and off the surface on an arc (up and a little right of the fingertip,
// rod swinging clockwise and steeper, the hand growing as it comes toward the viewer),
// and it slams straight back down on the same spot. The lift decelerates into the top
// (50-100 ms), the slam accelerates into the glass (33-50 ms, the blurriest frame is
// the one just before contact), it sits 30-70 ms, and a hard hit sometimes chatters
// with a second tiny contact 10-20 ms later. Flurries repeat every 115-170 ms and get
// taller as they get angrier. The plastic hand and metal rod are rigid: no bend, and
// the telescoping sections never slide.

struct TapBounce {
    /// Height as a fraction of the main lift.
    let height: CGFloat
    let up: CFTimeInterval
    let down: CFTimeInterval
}

/// What a tap leaves on the glass, drawn as rubber-hose cel effects on twos.
struct TapMark {
    /// Outer reach of the effect (pt, at pointer size 1).
    var radius: CGFloat
    /// Number of cel drawings, each held for 1/12 s.
    var drawings: Int
    /// Emanata: tapered dashes radiating from the hit.
    var dashes = 4
    /// Dash rings (2 = a second, wider ring a drawing later).
    var dashRings = 1
    /// Points on the pow starburst behind the hit (0 = none).
    var pow = 0
    /// Pow paint: 0 cream, 1 pale yellow, 2 faded red with a yellow core.
    var powTone = 0
    /// One drawing of inverse paint (solid ink star, cream rim) as the hit lands.
    var flash = false
    /// Little 5-point stars flung up and out.
    var stars = 0
    /// Teardrop plewds flung off the hit.
    var drops = 0
    /// Scalloped dust puffs.
    var puffs = 0
    /// Four-point sparkle crosses.
    var sparkles = 0
    /// Dizzy stars orbiting the hit.
    var squeans = 0
    /// Spiral dizzy curls.
    var curls = 0
    /// Zigzag vibration lines either side of the hand.
    var agitrons = false
    /// Speed lines along the slam, on the impact drawing.
    var streaks = 0
    /// Effect jitter in points on its first drawings (0 = still).
    var shake: CGFloat = 0
}

struct TapRecipe {
    /// Tip travel at the top of the wind-up, in hand heights.
    let lift: CGFloat
    /// Clockwise swing of hand + rod at the top (degrees).
    let swing: CGFloat
    /// Apparent size at the top (the hand comes toward the viewer).
    let grow: CGFloat
    let windUp: CFTimeInterval
    /// Hang at the top before the slam.
    let hang: CFTimeInterval
    let slam: CFTimeInterval
    /// Hand length along the finger at impact (1 = no squash).
    let squash: CGFloat
    let bounces: [TapBounce]
    /// Decaying rock about the fingertip after a hard hit (degrees).
    let wobble: CGFloat
    let mark: TapMark

    /// Time from the click to the fingertip hitting the glass.
    var impact: CFTimeInterval { windUp + hang + slam }

    /// The real wind-up is 50-100 ms; it is squeezed here so the hit lands within
    /// 65-95 ms of the click sound.
    static func forLevel(_ l: Int) -> TapRecipe {
        let chatter = TapBounce(height: 0.05, up: 0.012, down: 0.012)
        switch l {
        case ...1:
            // A polite single peck: a small lift, straight back down, nothing else.
            return TapRecipe(lift: 0.3, swing: 2, grow: 1.04, windUp: 0.040, hang: 0, slam: 0.026,
                             squash: 0.97, bounces: [], wobble: 0,
                             mark: TapMark(radius: 28, drawings: 3, dashes: 5))
        case 2:
            return TapRecipe(lift: 0.55, swing: 4, grow: 1.08, windUp: 0.044, hang: 0, slam: 0.028,
                             squash: 0.95, bounces: [chatter], wobble: 0,
                             mark: TapMark(radius: 32, drawings: 3, dashes: 6, puffs: 1))
        case 3:
            return TapRecipe(lift: 0.9, swing: 6, grow: 1.13, windUp: 0.048, hang: 0, slam: 0.030,
                             squash: 0.92, bounces: [chatter, TapBounce(height: 0.16, up: 0.05, down: 0.035)],
                             wobble: 0,
                             mark: TapMark(radius: 42, drawings: 5, dashes: 8, pow: 6, stars: 2, streaks: 2))
        case 4:
            return TapRecipe(lift: 1.4, swing: 9, grow: 1.22, windUp: 0.052, hang: 0.006, slam: 0.030,
                             squash: 0.89, bounces: [chatter, TapBounce(height: 0.3, up: 0.06, down: 0.04)],
                             wobble: 2.5,
                             mark: TapMark(radius: 52, drawings: 7, dashes: 8, pow: 8, powTone: 1, flash: true, stars: 3,
                                           drops: 2, puffs: 2, agitrons: true, streaks: 3))
        default:
            return TapRecipe(lift: 2.1, swing: 13, grow: 1.32, windUp: 0.056, hang: 0.006, slam: 0.032,
                             squash: 0.85,
                             bounces: [chatter, TapBounce(height: 0.42, up: 0.065, down: 0.042),
                                       TapBounce(height: 0.12, up: 0.04, down: 0.03)],
                             wobble: 4,
                             mark: TapMark(radius: 62, drawings: 8, dashes: 12, pow: 8, powTone: 2, flash: true,
                                           stars: 4, drops: 2, puffs: 2, squeans: 3, curls: 2,
                                           agitrons: true, streaks: 3, shake: 2))
        }
    }
}

/// Where things sit around the click point, in screen points (y up), relative to the tip.
struct TapGeometry {
    var handCenter: CGPoint
    var handRadius: CGFloat
    /// Unit direction the tip travels on the wind-up.
    var liftDir: CGPoint
    /// How far the tip travelled on the wind-up (pt).
    var lift: CGFloat
}

/// One tap effect as cel drawings: one path per drawing for each paint layer.
/// Layers stack bottom to top: outline, red, yellow, paint, rim, flash, lines, strokes.
struct TapCels {
    /// Ink under the painted shapes; stroked at 2x outlineWidth so it shows as an outline.
    var outline: [CGPath] = []
    /// Faded-red accent paint (the outer pow star on the wildest taps).
    var red: [CGPath] = []
    /// Pale-yellow accent paint (pow stars on hard taps, the odd flung star).
    var yellow: [CGPath] = []
    /// Cream cel paint: puffs, stars, drops, sparkles.
    var paint: [CGPath] = []
    /// Cream rim around the inverse hit-flash star (stroked at 2x outlineWidth).
    var rim: [CGPath] = []
    /// The one-drawing inverse hit flash: a solid ink star.
    var flash: [CGPath] = []
    /// Filled line work: emanata dashes, speed lines (line ink).
    var lines: [CGPath] = []
    /// Stroked line work: agitron zigzags and dizzy spirals (line ink, round caps).
    var strokes: [CGPath] = []
    var outlineWidth: CGFloat = 1.5
    var strokeWidth: CGFloat = 1.5
    /// Jitter of the whole effect, in points, on the first few drawings (0 = still).
    var shake: CGFloat = 0
    var drawings: Int { lines.count }
}

/// Rubber-hose (1920s-30s cartoon) impact flourishes, drawn as flat cel art: thick uniform
/// ink outlines with round joins, flat cream paint with at most a yellow or red accent,
/// bulbous shapes with teardrop ends, everything placed radially around the hit, and every
/// drawing re-jittered so the lines boil. Vocabulary from Mort Walker's comics symbols:
/// emanata (radiating dashes), a pow starburst, 5-point stars, plewds (teardrops),
/// briffits (dust puffs), agitrons (vibration zigzags), squeans (orbiting dizzy stars)
/// and spiral curls.
enum TapFX {
    static func at(_ ang: CGFloat, _ r: CGFloat, _ c: CGPoint = .zero) -> CGPoint {
        CGPoint(x: c.x + cos(ang) * r, y: c.y + sin(ang) * r)
    }

    /// `count` angles fanned across `span` radians centred on `mid`, each nudged a little.
    static func fan(_ count: Int, mid: CGFloat, span: CGFloat, jitter: CGFloat) -> [CGFloat] {
        guard count > 0 else { return [] }
        if count == 1 { return [mid + .random(in: -jitter...jitter)] }
        return (0..<count).map { i in
            mid - span / 2 + span * CGFloat(i) / CGFloat(count - 1) + .random(in: -jitter...jitter)
        }
    }

    /// `count` angles evenly round the full circle, jittered ±12°, with one gap left out
    /// (when there are six or more) so the ring never looks mechanical.
    static func ring(_ count: Int, offset: CGFloat) -> [CGFloat] {
        guard count > 0 else { return [] }
        let slots = count >= 6 ? count + 1 : count
        let skip = count >= 6 ? Int.random(in: 0..<slots) : -1
        let j: CGFloat = 12 * .pi / 180
        let step = 2 * CGFloat.pi / CGFloat(slots)
        return (0..<slots).filter { $0 != skip }.map { (i: Int) -> CGFloat in
            let base: CGFloat = offset + CGFloat(i) * step
            return base + CGFloat.random(in: -j...j)
        }
    }

    static func make(_ m: TapMark, radius R: CGFloat, geometry g: TapGeometry) -> TapCels {
        let n = max(1, m.drawings)
        func blank() -> [CGMutablePath] { (0..<n).map { _ in CGMutablePath() } }
        let outline = blank(), red = blank(), yellow = blank(), paint = blank()
        let rim = blank(), flash = blank(), lines = blank(), strokes = blank()
        // Ink about 9% of a painted shape's size, never thinner than 1.4 pt.
        let ow = max(1.4, R * 0.045)
        // The open side: straight away from the hand, which covers the other side.
        let away = atan2(-g.handCenter.y, -g.handCenter.x)

        /// A painted shape: ink outline under flat paint.
        func painted(_ p: CGPath, _ k: Int, into fill: [CGMutablePath]) {
            outline[k].addPath(p)
            fill[k].addPath(p)
        }

        // Pow starburst behind the hit: snaps in big, settles, holds while boiling, pops.
        let powR = R * (m.powTone == 2 ? 0.48 : 0.4)
        if m.pow > 0 {
            let life = min(n, 6)
            let rays = (0..<m.pow).map { _ in CGFloat.random(in: 0.72...1.0) }
            let rot = CGFloat.random(in: 0...(2 * .pi))
            for k in 0..<life {
                let scale: CGFloat = k == 0 ? 1.25 : k == 1 ? 0.95 : (k == life - 1 && life > 3 ? 1.12 : 1.0)
                let r = powR * scale
                let step: CGFloat = k == life - 1 && life > 3 ? 0.08 : 0
                let outer = starPath(points: m.pow, radius: r, rays: rays, inner: 0.52, rotation: rot + step)
                if k == 0 && m.flash {
                    // One drawing of inverse paint: solid ink star with a cream rim.
                    rim[k].addPath(outer)
                    flash[k].addPath(outer)
                    continue
                }
                switch m.powTone {
                case 2:
                    painted(outer, k, into: red)
                    let inner = starPath(points: m.pow, radius: r * 0.6, rays: rays, inner: 0.55, rotation: rot + step)
                    yellow[k].addPath(inner)
                case 1: painted(outer, k, into: yellow)
                default: painted(outer, k, into: paint)
                }
            }
        }

        // Emanata: short tapered dashes radiating from the hit, fat end in, on the first
        // three drawings (burst out, full length, thinning as they fly off).
        let push: CGFloat = m.pow > 0 ? 1.18 : 1
        let dashW = max(2.4, R * 0.09)
        for ringIndex in 0..<m.dashRings {
            let angles = ring(m.dashes / m.dashRings, offset: .random(in: 0...(2 * .pi)))
            let lens = angles.map { _ in CGFloat.random(in: 0.8...1.15) }
            let start = ringIndex            // the outer ring starts a drawing later
            let far: CGFloat = ringIndex == 0 ? 1 : 1.3
            let stages: [(CGFloat, CGFloat, CGFloat)] = [(0.55, 0.80, 1.0), (0.62, 1.02, 0.9), (0.88, 1.1, 0.55)]
            for (s, stage) in stages.enumerated() where start + s < n {
                for (i, a0) in angles.enumerated() {
                    let a = a0 + .random(in: -0.03...0.03)
                    let r0 = R * stage.0 * push * far
                    let r1 = r0 + (R * stage.1 * push * far - r0) * lens[i]
                    addWedge(lines[start + s], from: at(a, r0), to: at(a, r1), width: dashW * stage.2 * (ringIndex == 0 ? 1 : 0.8))
                }
            }
        }

        // Little 5-point stars flung up and out, turning 15° a drawing.
        let starAngles = fan(m.stars, mid: away + .random(in: -0.2...0.2), span: min(2.4, 0.8 * CGFloat(m.stars)), jitter: 0.2)
        for (si, a) in starAngles.enumerated() {
            let spin: CGFloat = (Bool.random() ? 1 : -1) * 15 * .pi / 180
            let size = R * 0.12 * .random(in: 0.85...1.15)
            let accent = m.powTone > 0 && si % 2 == 1
            for k in 0..<n {
                let p = n > 1 ? CGFloat(k) / CGFloat(n - 1) : 0
                let e = 1 - (1 - p) * (1 - p)
                let c = at(a, R * (0.45 + 0.7 * e), CGPoint(x: 0, y: R * 0.3 * sin(.pi * p)))
                let s = size * (k == 0 ? 1.25 : k == n - 1 ? 0.6 : 1)
                let star = starPath(points: 5, radius: s, rays: [1, 1, 1, 1, 1], inner: 0.48,
                                    rotation: spin * CGFloat(k), center: c)
                painted(star, k, into: accent ? yellow : paint)
            }
        }

        // Plewds: teardrops flung off the hit, round end leading, falling as they go.
        let dropAngles = fan(m.drops, mid: away + .random(in: -0.4...0.4), span: min(2.2, 0.9 * CGFloat(m.drops)), jitter: 0.25)
        for a in dropAngles {
            let size = R * 0.065 * .random(in: 0.85...1.15)
            let life = min(n, 5)
            for k in 0..<life {
                let p = life > 1 ? CGFloat(k) / CGFloat(life - 1) : 0
                let e = 1 - (1 - p) * (1 - p)
                let c = at(a, R * (0.5 + 0.6 * e), CGPoint(x: 0, y: -R * 0.3 * p * p))
                // Direction of travel, bending down with gravity.
                let dir = atan2(sin(a) - 0.9 * p, cos(a))
                let drop = CGMutablePath()
                addTeardrop(drop, center: c, radius: size * (k == 0 ? 0.8 : 1), direction: dir,
                            tail: k == 0 ? 3.4 : 2.4)
                painted(drop, k, into: paint)
            }
        }

        // Briffits: scalloped dust puffs that pop out on the diagonals, billow and break up.
        let puffAngles = fan(m.puffs, mid: away + .random(in: -0.3...0.3), span: min(3.2, 1.2 * CGFloat(m.puffs)), jitter: 0.2)
        for a in puffAngles {
            let size = R * (m.pow > 0 ? 0.13 : 0.2) * .random(in: 0.85...1.15)
            let scallops = Int.random(in: 5...7)
            let phase = CGFloat.random(in: 0...(2 * .pi))
            for k in 0..<n {
                let p = n > 1 ? CGFloat(k) / CGFloat(n - 1) : 0
                let dist = R * (m.pow > 0 ? 0.5 + 0.4 * (1 - (1 - p) * (1 - p)) : 0.4 + 0.25 * p)
                let c = at(a, dist, CGPoint(x: 0, y: R * 0.1 * p))
                let sc: CGFloat = k == 0 ? 0.6 : (p > 0.85 ? 0.9 : 1.0)
                let cloud = CGMutablePath()
                // Centre blob plus a ring of lobes; the lobes drift apart on the last drawings.
                let spread: CGFloat = p > 0.85 ? 1.35 : 1
                if p <= 0.85 { cloud.addEllipse(in: circle(c, size * sc * 0.75)) }
                for i in 0..<scallops {
                    let la = phase + CGFloat(i) / CGFloat(scallops) * 2 * .pi + .random(in: -0.15...0.15)
                    let lr = size * sc * .random(in: 0.42...0.52) * (p > 0.85 ? 0.7 : 1)
                    cloud.addEllipse(in: circle(at(la, size * sc * 0.62 * spread, c), lr))
                }
                painted(cloud, k, into: paint)
            }
        }

        // Sparkle crosses: twinkle once near the rim.
        let sparkAngles = fan(m.sparkles, mid: away + .random(in: -0.6...0.6), span: min(2.6, 1.4 * CGFloat(m.sparkles)), jitter: 0.25)
        for (i, a) in sparkAngles.enumerated() {
            let start = 1 + i % 2
            let dist = R * .random(in: 0.8...1.0)
            let sizes: [CGFloat] = [0.6, 1.0, 0.45]
            for j in 0..<sizes.count where start + j < n {
                let sp = CGMutablePath()
                addSparkle(sp, center: at(a, dist), radius: R * 0.15 * sizes[j], rotation: 0.15 * CGFloat(j))
                painted(sp, start + j, into: paint)
            }
        }

        // Squeans: little stars orbiting the hit on a flattened ellipse, one turn over the effect.
        if m.squeans > 0 {
            let centre = at(away, R * 0.2)
            let rx = R * 0.7, ry = R * 0.22
            let a0 = CGFloat.random(in: 0...(2 * .pi))
            let life = min(n, 6)
            for k in 1..<life {
                let turn = a0 + 2 * .pi * CGFloat(k - 1) / CGFloat(max(1, life - 1))
                for i in 0..<m.squeans {
                    let t = turn + CGFloat(i) / CGFloat(m.squeans) * 2 * .pi
                    let c = CGPoint(x: centre.x + cos(t) * rx, y: centre.y + sin(t) * ry)
                    // Stars at the back of the orbit (top) are smaller.
                    let s = R * 0.065 * (1 - 0.3 * (sin(t) + 1) / 2)
                    let star = starPath(points: 5, radius: s, rays: [1, 1, 1, 1, 1], inner: 0.48, rotation: t, center: c)
                    painted(star, k, into: i % 2 == 0 ? yellow : paint)
                }
            }
        }

        // Spiral curls: 1.5-turn dizzy spirals on the diagonals, turning 180° over their life.
        let curlAngles = fan(m.curls, mid: away, span: 2.2, jitter: 0.2)
        for (i, a) in curlAngles.enumerated() {
            let c = at(a, R * 0.95)
            let size = R * 0.14
            let dirSign: CGFloat = i % 2 == 0 ? 1 : -1
            for k in 1..<n {
                let p = CGFloat(k - 1) / CGFloat(max(1, n - 2))
                addSpiral(strokes[k], center: c, radius: size * (k == 1 ? 0.7 : 1), turns: 1.5,
                          rotation: dirSign * .pi * p, sign: dirSign)
            }
        }

        // Agitrons: zigzag vibration lines either side of the hand, jittering after the hit.
        if m.agitrons {
            let hc = g.handCenter
            let axis = atan2(hc.y, hc.x)
            let along = CGPoint(x: cos(axis), y: sin(axis))
            for k in 1..<min(4, n) {
                let wob: CGFloat = k % 2 == 1 ? 1 : -1
                for side: CGFloat in [1, -1] {
                    let perp = CGPoint(x: -along.y * side, y: along.x * side)
                    for j in 0..<2 {
                        let off = g.handRadius * 0.95 + R * (0.1 * CGFloat(j) + 0.025 * wob)
                        let mid = CGPoint(x: hc.x * 0.85 + perp.x * off, y: hc.y * 0.85 + perp.y * off)
                        let half = g.handRadius * (j == 0 ? 0.32 : 0.22)
                        addZigzag(strokes[k], from: CGPoint(x: mid.x - along.x * half, y: mid.y - along.y * half),
                                  to: CGPoint(x: mid.x + along.x * half, y: mid.y + along.y * half),
                                  amplitude: R * 0.045, zigs: 4, normal: perp)
                    }
                }
            }
        }

        // Speed lines left by the slam, on the impact drawing only.
        if m.streaks > 0 {
            let d = g.liftDir
            let perp = CGPoint(x: -d.y, y: d.x)
            let length = min(g.lift, R * 1.2) * 0.75
            for k in 0..<min(m.streaks >= 3 ? 2 : 1, n) {
                for j in 0..<m.streaks {
                    let off = (CGFloat(j) - CGFloat(m.streaks - 1) / 2) * g.handRadius * 0.55
                    let back = g.handRadius * (0.75 + 0.15 * CGFloat(k))
                    let s = CGPoint(x: g.handCenter.x * 0.35 + d.x * back + perp.x * off,
                                    y: g.handCenter.y * 0.35 + d.y * back + perp.y * off)
                    let l = length * .random(in: 0.75...1.1) * (k == 0 ? 1 : 0.5)
                    addWedge(lines[k], from: s, to: CGPoint(x: s.x + d.x * l, y: s.y + d.y * l),
                             width: R * 0.05 * (k == 0 ? 1 : 0.7))
                }
            }
        }

        return TapCels(outline: outline, red: red, yellow: yellow, paint: paint, rim: rim, flash: flash,
                       lines: lines, strokes: strokes, outlineWidth: ow, strokeWidth: max(1.4, R * 0.04),
                       shake: m.shake)
    }

    // MARK: Shapes

    static func circle(_ c: CGPoint, _ r: CGFloat) -> CGRect {
        CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)
    }

    /// A star with uneven ray lengths (fractions of `radius`) and each vertex nudged ±3%,
    /// so successive drawings boil. Outlines are stroked with round joins, which fattens
    /// and rounds the points.
    static func starPath(points: Int, radius r: CGFloat, rays: [CGFloat], inner: CGFloat,
                         rotation: CGFloat, center c: CGPoint = .zero) -> CGPath {
        let path = CGMutablePath()
        for i in 0..<(points * 2) {
            let a = rotation + .pi / 2 + CGFloat(i) * .pi / CGFloat(points) + .random(in: -0.03...0.03)
            let len = (i % 2 == 0 ? rays[(i / 2) % rays.count] : inner) * r * .random(in: 0.97...1.03)
            let p = at(a, len, c)
            i == 0 ? path.move(to: p) : path.addLine(to: p)
        }
        path.closeSubpath()
        return path
    }

    /// A dash that is fat and round at `a` and tapers to a small round tip at `b`.
    static func addWedge(_ path: CGMutablePath, from a: CGPoint, to b: CGPoint, width w: CGFloat) {
        let dx = b.x - a.x, dy = b.y - a.y
        let len = max(0.001, hypot(dx, dy))
        let nx = -dy / len, ny = dx / len
        let w0 = w / 2, w1 = max(0.3, w * 0.12)
        path.move(to: CGPoint(x: a.x + nx * w0, y: a.y + ny * w0))
        path.addLine(to: CGPoint(x: b.x + nx * w1, y: b.y + ny * w1))
        path.addLine(to: CGPoint(x: b.x - nx * w1, y: b.y - ny * w1))
        path.addLine(to: CGPoint(x: a.x - nx * w0, y: a.y - ny * w0))
        path.closeSubpath()
        path.addEllipse(in: circle(a, w0))
        path.addEllipse(in: circle(b, w1))
    }

    /// Teardrop with its round end at `center` facing `direction` and a pointed tail behind.
    static func addTeardrop(_ path: CGMutablePath, center c: CGPoint, radius r: CGFloat,
                            direction a: CGFloat, tail: CGFloat) {
        let back = at(a + .pi, r * tail, c)
        let ctrlL = at(a + .pi, r * 1.1, at(a + .pi / 2, r * 0.95, c))
        let ctrlR = at(a + .pi, r * 1.1, at(a - .pi / 2, r * 0.95, c))
        path.move(to: at(a + .pi / 2, r, c))
        path.addArc(center: c, radius: r, startAngle: a + .pi / 2, endAngle: a - .pi / 2, clockwise: true)
        path.addQuadCurve(to: back, control: ctrlR)
        path.addQuadCurve(to: at(a + .pi / 2, r, c), control: ctrlL)
        path.closeSubpath()
    }

    /// Four-point twinkle with pinched, curved sides; the vertical arms are longer.
    static func addSparkle(_ path: CGMutablePath, center c: CGPoint, radius r: CGFloat, rotation rot: CGFloat) {
        let tips = (0..<4).map { i in at(rot + .pi / 2 + CGFloat(i) * .pi / 2, i % 2 == 0 ? r : r * 0.72, c) }
        path.move(to: tips[0])
        for i in 0..<4 {
            let mid = rot + .pi / 2 + (CGFloat(i) + 0.5) * .pi / 2
            path.addQuadCurve(to: tips[(i + 1) % 4], control: at(mid, r * 0.14, c))
        }
        path.closeSubpath()
    }

    /// An Archimedean spiral from the centre out, for stroking.
    static func addSpiral(_ path: CGMutablePath, center c: CGPoint, radius r: CGFloat, turns: CGFloat,
                          rotation: CGFloat, sign: CGFloat) {
        let steps = 40
        let total = turns * 2 * .pi
        for i in 0...steps {
            let u = CGFloat(i) / CGFloat(steps)
            let p = at(rotation + sign * u * total, r * (0.08 + 0.92 * u) * .random(in: 0.97...1.03), c)
            i == 0 ? path.move(to: p) : path.addLine(to: p)
        }
    }

    /// A short zigzag from `a` to `b`, swinging ±amplitude along `normal`.
    static func addZigzag(_ path: CGMutablePath, from a: CGPoint, to b: CGPoint, amplitude: CGFloat,
                          zigs: Int, normal nrm: CGPoint) {
        path.move(to: a)
        for i in 1..<zigs {
            let u = CGFloat(i) / CGFloat(zigs)
            let s: CGFloat = i % 2 == 1 ? 1 : -1
            let amp = amplitude * .random(in: 0.85...1.15)
            path.addLine(to: CGPoint(x: a.x + (b.x - a.x) * u + nrm.x * amp * s,
                                     y: a.y + (b.y - a.y) * u + nrm.y * amp * s))
        }
        path.addLine(to: b)
    }
}
// END TapFX

@MainActor
final class OverlayController {
    private var windows: [OverlayWindow] = []
    private var pointers: [PointerLayers] = []
    private var timer: Timer?
    private var boilTimer: Timer?
    private var lastLocation = CGPoint(x: -1, y: -1)
    private var lastTick: CFTimeInterval = 0
    /// Roll and swing of the pointer in response to being moved.
    private var motion = PointerMotion()
    /// Turn the hand and trail the rod when the pointer is flicked sideways. Off when the
    /// user has asked the system to reduce motion.
    var rollsWhenMoved: Bool { !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    private var activeIndex = -1
    private(set) var isShown = false
    private var style: PointerStyle = .tinyHand
    private var scale: CGFloat = 1
    private var stickStyle: StickStyle = .solid
    private var stickColor: CGColor = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
    /// One effect at a time: a new tap replaces the previous one when it lands.
    private weak var currentMark: CALayer?
    /// Subtle hand-held drift about the fingertip between taps.
    var idleSway = true {
        didSet { pointers.forEach { $0.setIdleSway(idleSway) } }
    }

    init() {
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuildWindows() }
        }
    }

    func configure(style: PointerStyle, scale: CGFloat, stickStyle: StickStyle, stickColor: CGColor) {
        self.style = style
        self.scale = scale
        self.stickStyle = stickStyle
        self.stickColor = stickColor
        motion.reset()
        let ink = Ink.current
        for (i, p) in pointers.enumerated() {
            let backing = windows[i].screen?.backingScaleFactor ?? 2
            p.apply(PointerArt.make(style: style, scale: scale, backing: backing, rolling: true), contentsScale: backing,
                    ink: ink, stickStyle: stickStyle, stickColor: stickColor)
        }
    }

    func show() {
        guard !isShown else { return }
        isShown = true
        motion.reset()
        lastTick = 0
        rebuildWindows()
        timer = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.track() }
        }
        RunLoop.main.add(timer!, forMode: .common)
        // Old-cartoon "on twos": 12 drawings per second.
        boilTimer = Timer(timeInterval: 1.0 / 12.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.activeIndex >= 0, self.activeIndex < self.pointers.count else { return }
                self.pointers[self.activeIndex].advanceFrame()
            }
        }
        RunLoop.main.add(boilTimer!, forMode: .common)
        track(force: true)
    }

    func hide() {
        guard isShown else { return }
        isShown = false
        timer?.invalidate()
        timer = nil
        boilTimer?.invalidate()
        boilTimer = nil
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        pointers.removeAll()
        activeIndex = -1
    }

    private func rebuildWindows() {
        guard isShown else { return }
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        pointers.removeAll()
        let ink = Ink.current
        for screen in NSScreen.screens {
            let w = OverlayWindow(screen: screen)
            let p = PointerLayers()
            p.pointer.isHidden = true
            w.root.addSublayer(p.pointer)
            p.apply(PointerArt.make(style: style, scale: scale, backing: screen.backingScaleFactor, rolling: true),
                    contentsScale: screen.backingScaleFactor, ink: ink, stickStyle: stickStyle, stickColor: stickColor)
            p.setIdleSway(idleSway)
            w.orderFrontRegardless()
            windows.append(w)
            pointers.append(p)
        }
        activeIndex = -1
        track(force: true)
    }

    private func track(force: Bool = false) {
        let loc = NSEvent.mouseLocation
        let now = CACurrentMediaTime()
        // Feed the motion every tick, moving or not: a spring keeps going after the cursor stops.
        let wasResting = motion.isAtRest
        let rolls = rollsWhenMoved
        if !rolls, !wasResting { motion.reset() }
        if rolls, lastTick > 0, lastLocation.x >= 0, !force {
            let tilt = activeIndex >= 0 ? Double(pointers[activeIndex].art?.tilt ?? 0) : 0
            motion.step(moved: CGVector(dx: loc.x - lastLocation.x, dy: loc.y - lastLocation.y),
                        dt: now - lastTick, tilt: tilt)
        }
        lastTick = now
        let moving = !(wasResting && motion.isAtRest)
        guard force || moving || loc != lastLocation else { return }
        lastLocation = loc
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        var idx = windows.firstIndex { NSMouseInRect(loc, $0.frame, false) } ?? -1
        if idx == -1, !windows.isEmpty { idx = 0 }
        if idx != activeIndex {
            for (i, p) in pointers.enumerated() { p.pointer.isHidden = (i != idx) }
            activeIndex = idx
        }
        if idx >= 0 {
            let f = windows[idx].frame
            pointers[idx].pointer.position = CGPoint(x: loc.x - f.minX, y: loc.y - f.minY)
            pointers[idx].setMotion(rollStep: motion.rollStep, swing: CGFloat(motion.swing * .pi / 180))
        }
        CATransaction.commit()
    }

    // MARK: - Tap
    //
    // Each click is one lift-and-slam: the hand flicks up off the glass (up and a little
    // right, rod swinging clockwise, hand growing toward the viewer), slams back onto the
    // click point, squashes, chatters, and on harder levels rebounds and rocks. The tip
    // always comes to rest exactly on the click point. A click that arrives mid-tap
    // starts the next lift from wherever the hand is, so fast clicking reads as the
    // real toy's continuous flurry. The effects land with the fingertip.

    func tap(level: Int) {
        guard isShown else { return }
        track(force: true)
        guard activeIndex >= 0, let art = pointers[activeIndex].art else { return }
        let p = pointers[activeIndex]
        let root = windows[activeIndex].root
        let at = p.pointer.position
        let r = TapRecipe.forLevel(level)
        let backing = windows[activeIndex].screen?.backingScaleFactor ?? 2

        let ink = Ink.current
        if ink.dark != p.ink.dark { p.setInk(ink) }

        let liftDir = Self.liftDirection(art)
        animateBody(p, art: art, recipe: r, liftDir: liftDir)
        animateSquash(p, art: art, recipe: r)

        // Hand centre relative to the tip, in screen space.
        let v = CGPoint(x: art.size.width / 2 - art.hotspot.x, y: art.size.height / 2 - art.hotspot.y)
        let hc = CGPoint(x: v.x * cos(art.tilt) - v.y * sin(art.tilt), y: v.x * sin(art.tilt) + v.y * cos(art.tilt))
        let geo = TapGeometry(handCenter: hc, handRadius: 0.42 * max(art.size.width, art.size.height),
                              liftDir: liftDir, lift: r.lift * art.size.height)
        let cels = TapFX.make(r.mark, radius: r.mark.radius * max(0.6, scale), geometry: geo)

        let mark = makeMarkLayer(cels, ink: ink, backing: backing, delay: r.impact)
        mark.position = at
        if let old = currentMark { autoRemove(old, after: r.impact) }
        root.insertSublayer(mark, below: p.pointer)
        currentMark = mark
        autoRemove(mark, after: r.impact + Double(cels.drawings + 1) / 12.0 + 0.05)
    }

    /// The wind-up direction: up and a little right of the fingertip, 37° clockwise of
    /// the finger (for the 22° tiny hand that is 15° right of straight up, as measured).
    private static func liftDirection(_ art: PointerArt) -> CGPoint {
        let a = CGFloat.pi / 2 + art.tilt - 37 * .pi / 180
        return CGPoint(x: cos(a), y: sin(a))
    }

    private struct Pose {
        var lift: CGFloat = 0
        var swing: CGFloat = 0
        var grow: CGFloat = 1
        var rock: CGFloat = 0
    }

    /// Body transform: resting tilt, plus a clockwise swing / grow about the fingertip and
    /// a lift along `liftDir`. Pose() is exactly the resting transform.
    private func bodyTransform(_ art: PointerArt, _ q: Pose, liftDir: CGPoint) -> CATransform3D {
        var t = CATransform3DMakeScale(q.grow, q.grow, 1)
        t = CATransform3DConcat(t, CATransform3DMakeRotation(art.tilt - q.swing + q.rock, 0, 0, 1))
        return CATransform3DConcat(t, CATransform3DMakeTranslation(liftDir.x * q.lift, liftDir.y * q.lift, 0))
    }

    private func animateBody(_ p: PointerLayers, art: PointerArt, recipe r: TapRecipe, liftDir: CGPoint) {
        let H = art.size.height
        let deg = CGFloat.pi / 180
        let easeOut = CAMediaTimingFunction(controlPoints: 0.2, 0.75, 0.4, 1)
        let easeIn = CAMediaTimingFunction(controlPoints: 0.55, 0, 0.95, 0.55)
        let easeInOut = CAMediaTimingFunction(name: .easeInEaseOut)
        let linear = CAMediaTimingFunction(name: .linear)
        func lifted(_ f: CGFloat) -> Pose {
            Pose(lift: r.lift * H * f, swing: r.swing * deg * f, grow: 1 + (r.grow - 1) * f)
        }

        var keys: [(CFTimeInterval, Pose, CAMediaTimingFunction)] = []
        var t: CFTimeInterval = 0
        t += r.windUp; keys.append((t, lifted(1), easeOut))
        if r.hang > 0 { t += r.hang; keys.append((t, lifted(1.04), linear)) }
        t += r.slam; keys.append((t, Pose(), easeIn))
        for b in r.bounces {
            t += b.up; keys.append((t, lifted(b.height), easeOut))
            t += b.down; keys.append((t, Pose(), easeIn))
        }
        if r.wobble > 0 {
            for w: CGFloat in [1, -0.6, 0.3, 0] {
                t += 0.04; keys.append((t, Pose(rock: r.wobble * deg * w), easeInOut))
            }
        }
        t += 0.03; keys.append((t, Pose(), linear))

        // Start from wherever an earlier tap has the hand right now.
        let start = p.body.presentation()?.transform ?? bodyTransform(art, Pose(), liftDir: liftDir)
        let a = CAKeyframeAnimation(keyPath: "transform")
        a.values = [NSValue(caTransform3D: start)] + keys.map { NSValue(caTransform3D: bodyTransform(art, $0.1, liftDir: liftDir)) }
        a.keyTimes = [0] + keys.map { NSNumber(value: $0.0 / t) }
        a.timingFunctions = keys.map { $0.2 }
        a.duration = t
        p.body.add(a, forKey: "tap")
    }

    /// Hand-only squash and stretch about the fingertip: stretched along the finger as it
    /// slams, squashed flat on the glass, a small overshoot, then rest.
    private func animateSquash(_ p: PointerLayers, art: PointerArt, recipe r: TapRecipe) {
        let d = CGPoint(x: art.hotspot.x - art.size.width / 2, y: art.hotspot.y - art.size.height / 2)
        func about(_ sx: CGFloat, _ sy: CGFloat) -> NSValue {
            var t = CATransform3DMakeTranslation(-d.x, -d.y, 0)
            t = CATransform3DConcat(t, CATransform3DMakeScale(sx, sy, 1))
            return NSValue(caTransform3D: CATransform3DConcat(t, CATransform3DMakeTranslation(d.x, d.y, 0)))
        }
        let q = 1 - r.squash
        let hit = r.impact
        let slamStart = r.windUp + r.hang
        let start = p.hand.presentation()?.transform ?? CATransform3DIdentity
        var times: [CFTimeInterval] = [0, slamStart, hit - 0.012, hit, hit + 0.05, hit + 0.11]
        var values: [NSValue] = [NSValue(caTransform3D: start), about(1, 1),
                                 about(1 - q * 0.4, 1 + q * 0.7),   // stretched by speed
                                 about(1 + q * 0.6, 1 - q),         // squashed on the glass
                                 about(1 - q * 0.2, 1 + q * 0.3),   // springs back past round
                                 about(1, 1)]
        // A lighter squash for each rebound landing.
        var t = hit
        for b in r.bounces {
            t += b.up + b.down
            if t > times.last! + 0.005 {
                times.append(t); values.append(about(1 + q * 0.6 * b.height * 2, 1 - q * b.height * 2))
                times.append(t + 0.04); values.append(about(1, 1))
            }
        }
        let total = times.last!
        let a = CAKeyframeAnimation(keyPath: "transform")
        a.values = values
        a.keyTimes = times.map { NSNumber(value: $0 / total) }
        a.duration = total
        p.hand.add(a, forKey: "squash")
    }

    // MARK: - Effect layers

    private func autoRemove(_ layer: CALayer, after: CFTimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + after) { layer.removeFromSuperlayer() }
    }

    /// Builds the effect as stacked shape layers whose paths are swapped on twos
    /// (12 drawings per second, discrete keyframes), starting when the tip lands.
    private func makeMarkLayer(_ c: TapCels, ink: Ink, backing: CGFloat, delay: CFTimeInterval) -> CALayer {
        let container = CALayer()
        container.bounds = .zero
        let begin = CACurrentMediaTime() + delay
        let count = c.drawings + 1  // the last "drawing" is blank
        let duration = Double(count) / 12.0

        func discrete(_ key: String, _ values: [Any]) -> CAKeyframeAnimation {
            let a = CAKeyframeAnimation(keyPath: key)
            a.values = values
            a.keyTimes = (0...values.count - 1).map { NSNumber(value: Double($0) / Double(count)) } + [1]
            a.calculationMode = .discrete
            a.duration = duration
            a.beginTime = begin
            a.fillMode = .forwards
            a.isRemovedOnCompletion = false
            return a
        }

        func add(_ paths: [CGPath], _ configure: (CAShapeLayer) -> Void) {
            guard paths.contains(where: { !$0.isEmpty }) else { return }
            let s = CAShapeLayer()
            s.strokeColor = nil
            s.lineWidth = 0
            configure(s)
            s.path = CGMutablePath()
            s.contentsScale = backing
            s.add(discrete("path", paths + [CGMutablePath()]), forKey: "cels")
            container.addSublayer(s)
        }
        func outlined(_ s: CAShapeLayer, _ color: CGColor) {
            s.fillColor = color
            s.strokeColor = color
            s.lineWidth = c.outlineWidth * 2
            s.lineJoin = .round
            s.lineCap = .round
        }
        // On a dark desktop the ink outline vanishes, so a cream keyline sits under it.
        if ink.dark { add(c.outline) { outlined($0, ink.paint); $0.lineWidth = c.outlineWidth * 2 + 2.4 } }
        add(c.outline) { outlined($0, ink.outline) }
        add(c.red) { $0.fillColor = Ink.red }
        add(c.yellow) { $0.fillColor = Ink.yellow }
        add(c.paint) { $0.fillColor = ink.paint }
        add(c.rim) { outlined($0, ink.paint) }
        // The inverse flash is solid ink; on a dark desktop that reads as a hole, so it is red.
        add(c.flash) { $0.fillColor = ink.dark ? Ink.red : Ink.ink }
        add(c.lines) { $0.fillColor = ink.marks }
        add(c.strokes) {
            $0.fillColor = nil
            $0.strokeColor = ink.marks
            $0.lineWidth = c.strokeWidth
            $0.lineJoin = .round
            $0.lineCap = .round
        }
        if c.shake > 0 {
            // Jitter the whole effect on twos for the first few drawings.
            let steps = min(4, c.drawings)
            let offsets: [NSValue] = (0..<steps).map { k in
                let amp = c.shake * (1 - CGFloat(k) / CGFloat(steps))
                return NSValue(point: NSPoint(x: .random(in: -amp...amp), y: .random(in: -amp...amp)))
            } + [NSValue(point: .zero)]
            let a = discrete("position", offsets)
            a.isAdditive = true
            container.add(a, forKey: "shake")
        }
        return container
    }
}
