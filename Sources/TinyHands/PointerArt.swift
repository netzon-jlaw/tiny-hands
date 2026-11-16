import AppKit

/// A rendered pointer: bitmap plus where its tip (hotspot) is.
struct PointerArt {
    let image: CGImage
    /// Film frames cycled at ~12 fps: line-boil variants (name, name-b, name-c) with
    /// sepia toning and fresh grain/dust baked into each. frames[0] == image.
    let frames: [CGImage]
    /// Size in points.
    let size: CGSize
    /// Hotspot in points, measured from the bottom-left (layer coordinates, y up).
    let hotspot: CGPoint
    /// Resting tilt in radians (positive = counter-clockwise).
    let tilt: CGFloat
    /// Whether the telescopic stick makes sense for this style.
    let hasStick: Bool
    /// Wrist point in points (y up) where the stick attaches.
    let wrist: CGPoint

    static func make(style: PointerStyle, scale userScale: CGFloat, backing: CGFloat) -> PointerArt {
        let base: CGFloat = 54 * userScale
        let name: String
        let height: CGFloat
        let tilt: CGFloat
        switch style {
        case .tinyHand: name = "tiny-hand"; height = base * 1.1; tilt = 22 * .pi / 180
        case .middleChild: name = "middle-child"; height = base * 1.1; tilt = 0
        case .peace: name = "peace"; height = base * 1.1; tilt = 0
        case .thumbsUp: name = "thumbs-up"; height = base * 1.1; tilt = 0
        case .rockOn: name = "rock-on"; height = base * 1.1; tilt = 0
        case .highFive: name = "high-five"; height = base * 1.1; tilt = 0
        case .catPaw: name = "cat-paw"; height = base * 1.1; tilt = 18 * .pi / 180
        case .classicArrow: name = "classic-arrow"; height = base * 0.66; tilt = 0
        }
        // Boil variants share one viewBox, so they render to identical canvases.
        var raws = ["", "-b", "-c"].compactMap { renderSVG(name + $0, height: height, backing: backing) }
        if raws.isEmpty {
            raws = [style == .catPaw ? renderPaw(height: base * 1.05, backing: backing)
                                     : renderArrow(height: base * 0.62, backing: backing)]
        }
        let rect = raws.map(alphaRect).reduce(CGRect.null) { $0.union($1) }
        let cropped = raws.map { rect.isNull ? $0 : ($0.cropping(to: rect) ?? $0) }
        let size = CGSize(width: CGFloat(cropped[0].width) / backing, height: CGFloat(cropped[0].height) / backing)
        let tipPx = findTip(cropped[0], leftmost: style == .classicArrow)
        var hotspot = CGPoint(x: tipPx.x / backing, y: size.height - tipPx.y / backing)
        if style == .classicArrow && Bundle.main.url(forResource: "classic-arrow", withExtension: "svg", subdirectory: "Pointers") != nil {
            // The arrow's rounded outline sits ~7 units above its real corner at (9, 9) in a 92x140 viewBox.
            hotspot = CGPoint(x: size.width * 9 / 92, y: size.height * (1 - 9.0 / 140))
        }
        let wrist = CGPoint(x: size.width * 0.5, y: 2)
        // 6 film frames: boil variant cycles a/b/c, grain re-rolls every frame.
        let frames = (0..<6).map { vintage(cropped[$0 % cropped.count], seed: UInt64($0 + 1), backing: backing) }
        return PointerArt(image: frames[0], frames: frames, size: size, hotspot: hotspot, tilt: tilt,
                          hasStick: style != .classicArrow, wrist: wrist)
    }

    // MARK: - Vintage film look

    /// Light sepia toning, per-pixel film grain and a few dust specks, all kept inside the art's alpha.
    private static func vintage(_ img: CGImage, seed: UInt64, backing: CGFloat) -> CGImage {
        var (d, w, h) = pixels(img)
        var rng = SplitMix(seed: seed &* 0x9E37_79B9_7F4A_7C15)
        let grain: Float = 12
        for i in stride(from: 0, to: d.count, by: 4) {
            let a = Float(d[i + 3])
            guard a > 0 else { continue }
            let af = a / 255
            // Un-premultiply.
            var r = Float(d[i]) / af, g = Float(d[i + 1]) / af, b = Float(d[i + 2]) / af
            // Sepia, mixed in lightly (12%) so the toy colours stay true.
            let sr = 0.393 * r + 0.769 * g + 0.189 * b
            let sg = 0.349 * r + 0.686 * g + 0.168 * b
            let sb = 0.272 * r + 0.534 * g + 0.131 * b
            r = r * 0.88 + min(255, sr) * 0.12
            g = g * 0.88 + min(255, sg) * 0.12
            b = b * 0.88 + min(255, sb) * 0.12
            // Monochrome grain (sum of two uniforms ~ soft gaussian).
            let n = (rng.unit() + rng.unit() - 1) * grain
            r += n; g += n; b += n
            d[i] = UInt8(max(0, min(255, r)) * af)
            d[i + 1] = UInt8(max(0, min(255, g)) * af)
            d[i + 2] = UInt8(max(0, min(255, b)) * af)
        }
        // Dust: a few small dark or light specks on opaque pixels.
        let specks = Int(CGFloat(w * h) / (900 * backing * backing)) + 2
        for _ in 0..<specks {
            let cx = Int(rng.unit() * Float(w)), cy = Int(rng.unit() * Float(h))
            let radius = backing * CGFloat(0.4 + rng.unit() * 0.8)
            let dark = rng.unit() < 0.65
            let ri = Int(ceil(radius))
            for y in max(0, cy - ri)...min(h - 1, cy + ri) {
                for x in max(0, cx - ri)...min(w - 1, cx + ri) {
                    let dx = CGFloat(x - cx), dy = CGFloat(y - cy)
                    guard dx * dx + dy * dy <= radius * radius else { continue }
                    let j = (y * w + x) * 4
                    guard d[j + 3] > 250 else { continue }
                    let v: UInt8 = dark ? 40 : 250
                    d[j] = v; d[j + 1] = UInt8(Float(v) * 0.95); d[j + 2] = UInt8(Float(v) * 0.85)
                }
            }
        }
        let ctx = CGContext(data: &d, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return ctx.makeImage()!
    }

    private struct SplitMix {
        var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
        mutating func unit() -> Float { Float(next() >> 40) / Float(1 << 24) }
    }

    // MARK: - Rendering

    private static func bitmap(_ w: Int, _ h: Int) -> CGContext {
        CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    }

    private static var svgCache: [String: NSImage] = [:]

    /// Rasterises Resources/Pointers/<name>.svg to the given height (points).
    private static func renderSVG(_ name: String, height: CGFloat, backing: CGFloat) -> CGImage? {
        let img: NSImage
        if let cached = svgCache[name] {
            img = cached
        } else {
            guard let url = Bundle.main.url(forResource: name, withExtension: "svg", subdirectory: "Pointers"),
                  let loaded = NSImage(contentsOf: url), loaded.size.height > 0 else { return nil }
            svgCache[name] = loaded
            img = loaded
        }
        let pad: CGFloat = 4 * backing
        let h = height * backing
        let w = h * img.size.width / img.size.height
        let ctx = bitmap(Int(ceil(w + pad * 2)), Int(ceil(h + pad * 2)))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        img.draw(in: NSRect(x: pad, y: pad, width: w, height: h))
        NSGraphicsContext.restoreGraphicsState()
        return ctx.makeImage()
    }

    private static func renderPaw(height: CGFloat, backing: CGFloat) -> CGImage {
        let H = height * backing
        let W = H * 0.8
        let ctx = bitmap(Int(W + 8 * backing), Int(H + 8 * backing))
        ctx.translateBy(x: 4 * backing, y: 4 * backing)
        let lw = max(2, 0.05 * W)
        let fur = CGColor(srgbRed: 0.98, green: 0.80, blue: 0.56, alpha: 1)
        let outline = CGColor(srgbRed: 0.24, green: 0.16, blue: 0.12, alpha: 1)
        let bean = CGColor(srgbRed: 0.97, green: 0.56, blue: 0.67, alpha: 1)

        // Silhouette: arm + palm + toes (y up).
        let arm = CGRect(x: W * 0.30, y: 0, width: W * 0.40, height: H * 0.35)
        let palm = CGRect(x: W * 0.12, y: H * 0.18, width: W * 0.76, height: H * 0.48)
        let toes: [CGRect] = [
            CGRect(x: W * 0.02, y: H * 0.50, width: W * 0.26, height: H * 0.24),
            CGRect(x: W * 0.22, y: H * 0.66, width: W * 0.26, height: H * 0.30),
            CGRect(x: W * 0.52, y: H * 0.66, width: W * 0.26, height: H * 0.30),
            CGRect(x: W * 0.72, y: H * 0.50, width: W * 0.26, height: H * 0.24),
        ]
        let silhouette = CGMutablePath()
        silhouette.addRoundedRect(in: arm, cornerWidth: W * 0.1, cornerHeight: W * 0.1)
        silhouette.addEllipse(in: palm)
        toes.forEach { silhouette.addEllipse(in: $0) }

        // Outline pass then fill pass gives a clean merged cartoon outline.
        ctx.setLineWidth(lw * 2)
        ctx.setStrokeColor(outline)
        ctx.setLineJoin(.round)
        ctx.addPath(silhouette); ctx.strokePath()
        ctx.setFillColor(fur)
        ctx.addPath(silhouette); ctx.fillPath()

        // Beans.
        ctx.setFillColor(bean)
        let mainBean = CGMutablePath()
        mainBean.addEllipse(in: CGRect(x: W * 0.28, y: H * 0.26, width: W * 0.44, height: H * 0.28))
        ctx.addPath(mainBean); ctx.fillPath()
        for t in toes {
            ctx.fillEllipse(in: t.insetBy(dx: t.width * 0.24, dy: t.height * 0.24).offsetBy(dx: 0, dy: t.height * 0.04))
        }
        return ctx.makeImage()!
    }

    private static func renderArrow(height: CGFloat, backing: CGFloat) -> CGImage {
        let H = height * backing
        let u = H / 21.0
        let pad = 3 * u
        let ctx = bitmap(Int(14 * u + pad * 2), Int(H + pad * 2))
        // Classic arrow in y-down units, flipped into y-up.
        let pts: [(CGFloat, CGFloat)] = [(0, 0), (0, 17), (4, 13.2), (6.8, 20), (9.4, 18.9), (6.7, 12.4), (12, 12.4)]
        let path = CGMutablePath()
        for (i, p) in pts.enumerated() {
            let pt = CGPoint(x: pad + p.0 * u, y: pad + H - p.1 * u)
            i == 0 ? path.move(to: pt) : path.addLine(to: pt)
        }
        path.closeSubpath()
        ctx.setLineJoin(.round)
        ctx.setLineWidth(2.4 * u)
        ctx.setStrokeColor(.white)
        ctx.addPath(path); ctx.strokePath()
        ctx.setFillColor(.black)
        ctx.addPath(path); ctx.fillPath()
        return ctx.makeImage()!
    }

    // MARK: - Analysis

    private static func pixels(_ img: CGImage) -> (data: [UInt8], w: Int, h: Int) {
        let w = img.width, h = img.height
        var data = [UInt8](repeating: 0, count: w * h * 4)
        let ctx = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        return (data, w, h)
    }

    /// Bounding box of non-transparent pixels (top-left origin, as CGImage.cropping expects).
    private static func alphaRect(_ img: CGImage) -> CGRect {
        let (d, w, h) = pixels(img)
        var minX = w, minY = h, maxX = -1, maxY = -1
        for y in 0..<h {
            for x in 0..<w where d[(y * w + x) * 4 + 3] > 8 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return .null }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    /// Tip in pixels from the top-left: the topmost opaque row (averaged), or
    /// for the arrow, the top-left-most opaque pixel.
    private static func findTip(_ img: CGImage, leftmost: Bool) -> CGPoint {
        let (d, w, h) = pixels(img)
        for y in 0..<h {
            var xs: [Int] = []
            for x in 0..<w where d[(y * w + x) * 4 + 3] > 120 { xs.append(x) }
            if !xs.isEmpty {
                let x = leftmost ? CGFloat(xs.first!) : CGFloat(xs.reduce(0, +)) / CGFloat(xs.count)
                return CGPoint(x: x, y: CGFloat(y) + 1)
            }
        }
        return CGPoint(x: CGFloat(w) / 2, y: 0)
    }
}
