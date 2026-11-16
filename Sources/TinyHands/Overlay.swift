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

/// The pointer layer tree: pointer (at mouse) → sway (idle rock, pivot = fingertip)
/// → body (tilt, anchor at tip) → stick (rod) + hand.
/// The stick is one long rod continuing the hand's axis out of the cuff: the drawn
/// telescoping rod from stick.svg when it is bundled, otherwise a gradient that fades out.
final class PointerLayers {
    let pointer = CALayer()
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
    var art: PointerArt?
    var ink = Ink(dark: false)
    private var frameIndex = 0

    /// Line boil + film grain: step to the next pre-rendered film frame.
    func advanceFrame() {
        guard let art, art.frames.count > 1 else { return }
        frameIndex = (frameIndex + 1) % art.frames.count
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        hand.contents = art.frames[frameIndex]
        CATransaction.commit()
    }

    init() {
        pointer.bounds = .zero
        sway.bounds = .zero
        sway.position = .zero
        pointer.addSublayer(sway)
        sway.addSublayer(body)
        body.addSublayer(stick)
        body.addSublayer(hand)
        // The glove casts no drop shadow; it is flat cel art.
        hand.shadowOpacity = 0
        stick.addSublayer(rod)
        stick.addSublayer(rodArt)
        rodArt.isHidden = true
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

    func apply(_ art: PointerArt, contentsScale: CGFloat, ink: Ink) {
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
        hand.contents = art.image
        hand.contentsScale = contentsScale
        hand.contentsGravity = .resize

        // A ~59 pt glove on a ~330 pt rod, hanging from the wrist along the hand's axis.
        let len = art.size.height * 5.6
        stick.isHidden = !art.hasStick
        stick.frame = CGRect(x: art.wrist.x, y: art.wrist.y, width: 0, height: 0)

        if art.hasStick, let svg = Self.stickSVG {
            let w = len * svg.size.width / svg.size.height
            if let img = Self.renderStick(svg, size: CGSize(width: w, height: len), backing: contentsScale) {
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

/// What a tap leaves on the glass, drawn as 1930s cel effects on twos.
struct TapMark {
    /// Outer reach of the effect (pt, at pointer size 1).
    var radius: CGFloat
    /// Number of cel drawings, each held for 1/12 s.
    var drawings: Int
    /// Weight of the squash-and-stretch impact ring (0 = none).
    var ring: CGFloat = 1
    /// A second, wider ring a drawing later.
    var echo = false
    /// The ring breaks into brush segments on its last drawing.
    var breakRing = false
    /// Short "plink" flecks of line flying off the contact.
    var plinks = 0
    /// Ink-outlined dust puffs.
    var puffs = 0
    /// Four-point sparkle crosses.
    var sparkles = 0
    /// Little five-point stars thrown up and out.
    var stars = 0
    /// Vibration lines either side of the hand.
    var shakes = false
    /// Speed lines along the slam, on the impact drawing.
    var streaks = 0
    /// Tiny ink droplets.
    var flecks = 0
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
                             mark: TapMark(radius: 24, drawings: 3, ring: 0.7, plinks: 3))
        case 2:
            return TapRecipe(lift: 0.55, swing: 4, grow: 1.08, windUp: 0.044, hang: 0, slam: 0.028,
                             squash: 0.95, bounces: [chatter], wobble: 0,
                             mark: TapMark(radius: 32, drawings: 4, ring: 0.85, plinks: 5, puffs: 1, sparkles: 1))
        case 3:
            return TapRecipe(lift: 0.9, swing: 6, grow: 1.13, windUp: 0.048, hang: 0, slam: 0.030,
                             squash: 0.92, bounces: [chatter, TapBounce(height: 0.16, up: 0.05, down: 0.035)],
                             wobble: 0,
                             mark: TapMark(radius: 42, drawings: 5, ring: 1, plinks: 6, puffs: 2, sparkles: 2,
                                           streaks: 2))
        case 4:
            return TapRecipe(lift: 1.4, swing: 9, grow: 1.22, windUp: 0.052, hang: 0.006, slam: 0.030,
                             squash: 0.89, bounces: [chatter, TapBounce(height: 0.3, up: 0.06, down: 0.04)],
                             wobble: 2.5,
                             mark: TapMark(radius: 52, drawings: 6, ring: 1.15, breakRing: true, plinks: 7,
                                           puffs: 3, sparkles: 2, shakes: true, streaks: 3))
        default:
            return TapRecipe(lift: 2.1, swing: 13, grow: 1.32, windUp: 0.056, hang: 0.006, slam: 0.032,
                             squash: 0.85,
                             bounces: [chatter, TapBounce(height: 0.42, up: 0.065, down: 0.042),
                                       TapBounce(height: 0.12, up: 0.04, down: 0.03)],
                             wobble: 4,
                             mark: TapMark(radius: 62, drawings: 7, ring: 1.3, echo: true, breakRing: true,
                                           plinks: 8, puffs: 5, sparkles: 2, stars: 3, shakes: true,
                                           streaks: 3, flecks: 6))
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
struct TapCels {
    /// Impact rings (even-odd fill, line ink).
    var ring: [CGPath] = []
    /// Plinks, shake lines, streaks, flecks (line ink).
    var lines: [CGPath] = []
    /// Ink under the painted shapes; stroked at 2x outlineWidth so it shows as an outline.
    var outline: [CGPath] = []
    /// Sepia shade of the painted shapes.
    var shade: [CGPath] = []
    /// Cream paint, offset up-left so a sepia crescent shows bottom-right.
    var paint: [CGPath] = []
    var outlineWidth: CGFloat = 1.5
    var drawings: Int { ring.count }
}

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

    static func make(_ m: TapMark, radius R: CGFloat, geometry g: TapGeometry) -> TapCels {
        let n = max(1, m.drawings)
        let ring = (0..<n).map { _ in CGMutablePath() }
        let lines = (0..<n).map { _ in CGMutablePath() }
        let outline = (0..<n).map { _ in CGMutablePath() }
        let shade = (0..<n).map { _ in CGMutablePath() }
        let paint = (0..<n).map { _ in CGMutablePath() }
        let ow = max(1.2, R * 0.04)
        // The open side: straight away from the hand, which covers the other side.
        let away = atan2(-g.handCenter.y, -g.handCenter.x)

        // Impact ring: squashes and stretches as it spreads and thins.
        if m.ring > 0 {
            let life = min(n, 4)
            for k in 0..<life {
                addRing(ring[k], k: k, life: life, R: R, weight: m.ring, broken: m.breakRing && k == life - 1)
            }
            if m.echo && n > 1 {
                let life2 = min(n - 1, 3)
                for k in 0..<life2 {
                    addRing(ring[k + 1], k: k, life: life2, R: R * 1.25, weight: m.ring * 0.55,
                            broken: k == life2 - 1)
                }
            }
        }

        // Plinks: thin brush flecks flying off the hit, in the first three drawings.
        let plinkAngles = fan(m.plinks, mid: away, span: min(4.6, 0.95 * CGFloat(m.plinks)), jitter: 0.12)
        let plinkLen = plinkAngles.map { _ in CGFloat.random(in: 0.75...1.15) }
        for k in 0..<min(3, n) {
            let kk = CGFloat(k)
            for (i, a0) in plinkAngles.enumerated() {
                let a = a0 + .random(in: -0.04...0.04)
                let r0 = R * (0.40 + 0.24 * kk) * .random(in: 0.95...1.05)
                let len = R * (0.30 - 0.07 * kk) * plinkLen[i]
                addSpike(lines[k], from: at(a, r0), to: at(a, r0 + len), width: R * 0.07 * (1 - 0.28 * kk))
            }
        }

        // Dust puffs: pop out of the hit, billow, drift outward and break up.
        let puffAngles = fan(m.puffs, mid: away + .random(in: -0.3...0.3),
                             span: min(3.8, 1.0 * CGFloat(m.puffs)), jitter: 0.22)
        for a in puffAngles {
            let size = R * 0.15 * .random(in: 0.85...1.15)
            let lobes: [(CGFloat, CGFloat, CGFloat)] = [(0, 0, 1)] + (0..<4).map { i in
                (CGFloat(i) * .pi / 2 + .random(in: -0.4...0.4), .random(in: 0.55...0.7), .random(in: 0.6...0.78))
            }
            for k in 0..<n {
                let p = n > 1 ? CGFloat(k) / CGFloat(n - 1) : 0
                let dist = R * (0.34 + 0.5 * (1 - (1 - p) * (1 - p)))
                let c = at(a, dist, CGPoint(x: 0, y: R * 0.08 * p))
                let sc = pow(sin(.pi * (0.14 + 0.78 * p)), 0.6)
                let breakup = max(0, p - 0.62) * 1.6
                var circles: [(CGPoint, CGFloat)] = []
                for (li, lobe) in lobes.enumerated() {
                    if li == 0 && breakup > 0.3 { continue }
                    let off = size * sc * lobe.1 * (1 + breakup)
                    let r = size * sc * lobe.2 * .random(in: 0.93...1.07) * (1 - breakup * 0.3)
                    circles.append((at(lobe.0, off, c), max(0.5, r)))
                }
                addPainted(circles: circles, ow: ow, k: k, outline: outline, shade: shade, paint: paint)
            }
        }

        // Sparkle crosses: twinkle once near the edge of the hit.
        let sparkAngles = fan(m.sparkles, mid: away + .random(in: -0.5...0.5),
                              span: min(2.6, 1.3 * CGFloat(m.sparkles)), jitter: 0.25)
        for (i, a) in sparkAngles.enumerated() {
            let start = i % 2
            let dist = R * .random(in: 0.78...0.98)
            let sizes: [CGFloat] = [0.55, 1.0, 0.7, 0.35]
            let rot0 = CGFloat.random(in: -0.3...0.3)
            for j in 0..<sizes.count where start + j < n {
                let path = CGMutablePath()
                addSparkle(path, center: at(a, dist * (1 + 0.05 * CGFloat(j))), radius: R * 0.16 * sizes[j],
                           rotation: rot0 + 0.2 * CGFloat(j))
                outline[start + j].addPath(path, transform: CGAffineTransform(translationX: ow * 0.3, y: -ow * 0.3))
                paint[start + j].addPath(path)
            }
        }

        // Little stars thrown up and out in an arc, tumbling.
        let starAngles = fan(m.stars, mid: away + .random(in: -0.2...0.2), span: 2.0, jitter: 0.2)
        for a in starAngles {
            let spin = CGFloat.random(in: 0.35...0.6) * (Bool.random() ? 1 : -1)
            let size = R * 0.11 * .random(in: 0.85...1.15)
            for k in 0..<n {
                let p = n > 1 ? CGFloat(k) / CGFloat(n - 1) : 0
                let c = at(a, R * (0.35 + 0.8 * p), CGPoint(x: 0, y: R * 0.35 * sin(.pi * p)))
                let s = size * (k == 0 ? 0.6 : 1 - 0.35 * p)
                let star = CGMutablePath()
                addStar(star, center: c, radius: s, inner: 0.46, points: 5, rotation: spin * CGFloat(k))
                let lit = CGMutablePath()
                addStar(lit, center: CGPoint(x: c.x - s * 0.1, y: c.y + s * 0.1), radius: s * 0.8, inner: 0.46,
                        points: 5, rotation: spin * CGFloat(k))
                outline[k].addPath(star, transform: CGAffineTransform(translationX: ow * 0.3, y: -ow * 0.3))
                shade[k].addPath(star)
                paint[k].addPath(lit)
            }
        }

        // Vibration lines either side of the hand, jittering in and out after the hit.
        if m.shakes {
            let hc = g.handCenter
            let axis = atan2(hc.y, hc.x)
            for k in 1..<min(4, n) {
                let wobble: CGFloat = k % 2 == 1 ? 1 : -1
                for side in [axis + .pi / 2, axis - .pi / 2] {
                    for j in 0..<2 {
                        let r = g.handRadius * 1.02 + R * (0.12 * CGFloat(j) + 0.03 * wobble)
                        let half: CGFloat = j == 0 ? 0.32 : 0.24
                        let mid = side + .random(in: -0.05...0.05)
                        addArcLens(lines[k], center: hc, radius: r, from: mid - half, to: mid + half,
                                   width: R * 0.05 * (1 - 0.2 * CGFloat(k - 1)))
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
                    addSpike(lines[k], from: s, to: CGPoint(x: s.x + d.x * l, y: s.y + d.y * l),
                             width: R * 0.04 * (k == 0 ? 1 : 0.7))
                }
            }
        }

        // Ink droplets.
        let fleckAngles = fan(m.flecks, mid: away, span: 4.2, jitter: 0.25)
        for a in fleckAngles {
            let speed = CGFloat.random(in: 0.85...1.2)
            for k in 0..<min(3, n) {
                let kk = CGFloat(k)
                let r0 = R * (0.55 + 0.32 * kk) * speed
                let len = R * 0.09 * (1 - 0.3 * kk)
                addSpike(lines[k], from: at(a, r0), to: at(a, r0 + len), width: R * 0.09 * (1 - 0.3 * kk))
            }
        }

        return TapCels(ring: ring, lines: lines, outline: outline, shade: shade, paint: paint, outlineWidth: ow)
    }

    // MARK: Shapes

    /// A brush-inked ring: thick on the shadow side (bottom-right), thin on the light side,
    /// wobbly, squashed then stretched as it spreads; optionally broken into segments.
    static func addRing(_ path: CGMutablePath, k: Int, life: Int, R: CGFloat, weight: CGFloat, broken: Bool) {
        let p = life > 1 ? CGFloat(k) / CGFloat(life - 1) : 0
        let e = 1 - (1 - p) * (1 - p)
        let r = R * (0.24 + 0.6 * e)
        let squash: [(CGFloat, CGFloat)] = [(1.16, 0.84), (0.93, 1.07), (1.03, 0.97), (1, 1)]
        let (sx, sy) = squash[min(k, squash.count - 1)]
        let thick = R * (0.10 * weight * (1 - 0.7 * p) + 0.012)
        func shadow(_ ang: CGFloat) -> CGFloat { 0.45 + 0.55 * (1 + cos(ang + .pi / 4)) / 2 }

        if broken {
            let segs = 5
            let spin = CGFloat.random(in: 0...(2 * .pi))
            for i in 0..<segs {
                let mid = spin + CGFloat(i) / CGFloat(segs) * 2 * .pi + .random(in: -0.12...0.12)
                let half = .pi / CGFloat(segs) * .random(in: 0.45...0.62)
                addArcLens(path, center: .zero, radius: r, from: mid - half, to: mid + half,
                           width: thick * 1.6 * shadow(mid))
            }
            return
        }
        let ph1 = CGFloat.random(in: 0...(2 * .pi)), ph2 = CGFloat.random(in: 0...(2 * .pi))
        let steps = 56
        var outer: [CGPoint] = [], inner: [CGPoint] = []
        for i in 0..<steps {
            let ang = CGFloat(i) / CGFloat(steps) * 2 * .pi
            let rr = r * (1 + 0.03 * sin(3 * ang + ph1) + 0.018 * sin(5 * ang + ph2))
            let ri = rr - thick * shadow(ang)
            outer.append(CGPoint(x: cos(ang) * rr * sx, y: sin(ang) * rr * sy))
            inner.append(CGPoint(x: cos(ang) * ri * sx, y: sin(ang) * ri * sy))
        }
        path.addLines(between: outer)
        path.closeSubpath()
        path.addLines(between: inner)
        path.closeSubpath()
    }

    /// Painted cel shape from overlapping circles: ink outline, sepia shade, cream paint.
    static func addPainted(circles: [(CGPoint, CGFloat)], ow: CGFloat, k: Int,
                           outline: [CGMutablePath], shade: [CGMutablePath], paint: [CGMutablePath]) {
        for (c, r) in circles {
            // The outline sits a touch down-right, so the ink is heavier on the shadow side.
            outline[k].addEllipse(in: CGRect(x: c.x - r + ow * 0.35, y: c.y - r - ow * 0.35, width: 2 * r, height: 2 * r))
            shade[k].addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
            let pr = r * 0.78
            let pc = CGPoint(x: c.x - r * 0.16, y: c.y + r * 0.16)
            paint[k].addEllipse(in: CGRect(x: pc.x - pr, y: pc.y - pr, width: 2 * pr, height: 2 * pr))
        }
    }

    /// A lens-shaped brush stroke from `a` to `b`.
    static func addSpike(_ path: CGMutablePath, from a: CGPoint, to b: CGPoint, width: CGFloat) {
        let dx = b.x - a.x, dy = b.y - a.y
        let len = max(0.001, hypot(dx, dy))
        let nx = -dy / len * width, ny = dx / len * width
        let m = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        path.move(to: a)
        path.addQuadCurve(to: b, control: CGPoint(x: m.x + nx, y: m.y + ny))
        path.addQuadCurve(to: a, control: CGPoint(x: m.x - nx, y: m.y - ny))
        path.closeSubpath()
    }

    /// A curved brush stroke along a circle, pointed at both ends.
    static func addArcLens(_ path: CGMutablePath, center c: CGPoint, radius r: CGFloat,
                           from a0: CGFloat, to a1: CGFloat, width w: CGFloat) {
        let steps = 14
        var outer: [CGPoint] = [], inner: [CGPoint] = []
        for i in 0...steps {
            let u = CGFloat(i) / CGFloat(steps)
            let a = a0 + (a1 - a0) * u
            let half = w * 0.5 * sin(.pi * u)
            outer.append(at(a, r + half, c))
            inner.append(at(a, r - half, c))
        }
        path.addLines(between: outer + inner.reversed())
        path.closeSubpath()
    }

    /// Four-point twinkle with pinched, curved sides; the vertical arms are longer.
    static func addSparkle(_ path: CGMutablePath, center c: CGPoint, radius r: CGFloat, rotation rot: CGFloat) {
        let tips = (0..<4).map { i in at(rot + .pi / 2 + CGFloat(i) * .pi / 2, i % 2 == 0 ? r : r * 0.72, c) }
        path.move(to: tips[0])
        for i in 0..<4 {
            let mid = rot + .pi / 2 + (CGFloat(i) + 0.5) * .pi / 2
            path.addQuadCurve(to: tips[(i + 1) % 4], control: at(mid, r * 0.12, c))
        }
        path.closeSubpath()
    }

    static func addStar(_ path: CGMutablePath, center c: CGPoint, radius r: CGFloat, inner: CGFloat,
                        points: Int, rotation: CGFloat) {
        for i in 0..<(points * 2) {
            let a = rotation + .pi / 2 + CGFloat(i) * .pi / CGFloat(points)
            let p = at(a, i % 2 == 0 ? r : r * inner, c)
            i == 0 ? path.move(to: p) : path.addLine(to: p)
        }
        path.closeSubpath()
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
    private var activeIndex = -1
    private(set) var isShown = false
    private var style: PointerStyle = .tinyHand
    private var scale: CGFloat = 1
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

    func configure(style: PointerStyle, scale: CGFloat) {
        self.style = style
        self.scale = scale
        let ink = Ink.current
        for (i, p) in pointers.enumerated() {
            let backing = windows[i].screen?.backingScaleFactor ?? 2
            p.apply(PointerArt.make(style: style, scale: scale, backing: backing), contentsScale: backing, ink: ink)
        }
    }

    func show() {
        guard !isShown else { return }
        isShown = true
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
            p.apply(PointerArt.make(style: style, scale: scale, backing: screen.backingScaleFactor),
                    contentsScale: screen.backingScaleFactor, ink: ink)
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
        guard force || loc != lastLocation else { return }
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

        func add(_ paths: [CGPath], _ configure: (CAShapeLayer) -> Void) {
            guard paths.contains(where: { !$0.isEmpty }) else { return }
            let s = CAShapeLayer()
            s.strokeColor = nil
            s.lineWidth = 0
            configure(s)
            s.path = CGMutablePath()
            s.contentsScale = backing
            let a = CAKeyframeAnimation(keyPath: "path")
            a.values = paths + [CGMutablePath()]
            a.keyTimes = (0...count).map { NSNumber(value: Double($0) / Double(count)) }
            a.calculationMode = .discrete
            a.duration = duration
            a.beginTime = begin
            a.fillMode = .forwards
            a.isRemovedOnCompletion = false
            s.add(a, forKey: "cels")
            container.addSublayer(s)
        }
        add(c.ring) { $0.fillColor = ink.marks; $0.fillRule = .evenOdd }
        add(c.lines) { $0.fillColor = ink.marks }
        add(c.outline) {
            $0.fillColor = ink.outline
            $0.strokeColor = ink.outline
            $0.lineWidth = c.outlineWidth * 2
            $0.lineJoin = .round
        }
        add(c.shade) { $0.fillColor = ink.shade }
        add(c.paint) { $0.fillColor = ink.paint }
        return container
    }
}
