// Composites SVG/PNG files with NSImage into a PNG sheet.
// Usage: swift render.swift job.txt
// Job lines:
//   canvas W H R G B          (0-255 background)
//   rect X Y W H R G B        (filled rect, top-left origin)
//   img PATH X Y W H          (draw image with .sourceOver into the box)
//   save PATH
//   tip PATH SIZEH            (report topmost opaque pixel of PATH rendered SIZEH px tall)
import AppKit

let job = try! String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8)
var rep: NSBitmapImageRep? = nil
var H = 0

func flipY(_ y: Double, _ h: Double) -> Double { Double(H) - y - h }

for raw in job.split(separator: "\n") {
  let p = raw.split(separator: " ").map(String.init)
  if p.isEmpty { continue }
  switch p[0] {
  case "canvas":
    let w = Int(p[1])!, h = Int(p[2])!
    H = h
    rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep!)
    NSColor(deviceRed: Double(p[3])!/255, green: Double(p[4])!/255, blue: Double(p[5])!/255, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: w, height: h).fill()
  case "rect":
    let x = Double(p[1])!, y = Double(p[2])!, w = Double(p[3])!, h = Double(p[4])!
    NSColor(deviceRed: Double(p[5])!/255, green: Double(p[6])!/255, blue: Double(p[7])!/255, alpha: 1).setFill()
    NSRect(x: x, y: flipY(y, h), width: w, height: h).fill()
  case "img":
    let x = Double(p[2])!, y = Double(p[3])!, w = Double(p[4])!, h = Double(p[5])!
    guard let im = NSImage(contentsOf: URL(fileURLWithPath: p[1])) else { print("FAILED to load", p[1]); continue }
    im.draw(in: NSRect(x: x, y: flipY(y, h), width: w, height: h), from: .zero, operation: .sourceOver, fraction: 1)
  case "save":
    NSGraphicsContext.restoreGraphicsState()
    try! rep!.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: p[1]))
    print("saved", p[1])
  case "tip":
    let h = Int(p[2])!
    guard let im = NSImage(contentsOf: URL(fileURLWithPath: p[1])) else { print("FAILED", p[1]); continue }
    let w = Int((Double(h) * im.size.width / im.size.height).rounded())
    let r = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8,
                             samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                             colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: r)
    im.draw(in: NSRect(x: 0, y: 0, width: w, height: h), from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    var top = -1, xs: [Int] = []
    var minx = w, maxx = -1, maxy = -1
    for y in 0..<h {
      for x in 0..<w {
        let a = r.colorAt(x: x, y: y)!.alphaComponent
        if a > 0.5 {
          if top < 0 { top = y }
          if y == top { xs.append(x) }
          minx = min(minx, x); maxx = max(maxx, x); maxy = max(maxy, y)
        }
      }
    }
    let s = Double(h) / im.size.height
    let cx = xs.isEmpty ? -1 : Double(xs.first! + xs.last!) / 2 + 0.5
    print(String(format: "%@ tip=(%.2f, %.2f) bbox x %.2f..%.2f y %.2f..%.2f", (p[1] as NSString).lastPathComponent,
                 cx / s, Double(top) / s, Double(minx) / s, Double(maxx + 1) / s, Double(top) / s, Double(maxy + 1) / s))
  default: break
  }
}
