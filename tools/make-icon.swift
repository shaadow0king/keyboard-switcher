// Draws Mistype's app icon: Latin A and Cyrillic Я on two tiles with a pair of swap arrows,
// on an indigo-violet tile. At 64 px and below the arrows are left out so the letters stay readable.
// Run: swift tools/make-icon.swift <out.png> [size]
import AppKit

let args = CommandLine.arguments
let out = args.count > 1 ? args[1] : "AppIcon-1024.png"
let size = CGFloat(Double(args.count > 2 ? args[2] : "1024") ?? 1024)
let s = size / 1024
let small = size <= 64

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

func rgb(_ hex: Int, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: a)
}
let violet = 0x5B4BF0, deep = 0x2A1E8F, coral = 0xFF7A6B
func R(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect { NSRect(x: x * s, y: y * s, width: w * s, height: h * s) }
func rounded(_ px: CGFloat, _ weight: NSFont.Weight) -> NSFont {
    let base = NSFont.systemFont(ofSize: px * s, weight: weight)
    return NSFont(descriptor: base.fontDescriptor.withDesign(.rounded)!, size: px * s)!
}
func glyph(_ text: String, _ font: NSFont, _ color: NSColor, cx: CGFloat, cy: CGFloat, flip: Bool = false, shadow: Bool = true) {
    let str = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
    let b = str.size()
    ctx.saveGState()
    if shadow { ctx.setShadow(offset: CGSize(width: 0, height: -12 * s), blur: 28 * s, color: rgb(0x14093D, 0.4).cgColor) }
    ctx.translateBy(x: cx * s, y: cy * s)
    if flip { ctx.scaleBy(x: -1, y: 1) }
    str.draw(at: NSPoint(x: -b.width / 2, y: -b.height / 2 - font.descender / 2))
    ctx.restoreGState()
}
func roundedLine(_ path: NSBezierPath, _ color: NSColor, _ width: CGFloat) {
    color.setStroke(); path.lineWidth = width * s; path.lineCapStyle = .round; path.lineJoinStyle = .round; path.stroke()
}

// Tile: macOS icon grid, indigo → violet with a soft glow at the top.
let tile = NSBezierPath(roundedRect: R(100, 100, 824, 824), xRadius: 185 * s, yRadius: 185 * s)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10 * s), blur: 28 * s, color: rgb(0x000000, 0.28).cgColor)
rgb(violet).setFill(); tile.fill()
ctx.restoreGState()
NSGradient(colors: [rgb(0x8B7CFF), rgb(violet), rgb(deep)], atLocations: [0, 0.5, 1], colorSpace: .sRGB)!.draw(in: tile, angle: -90)
ctx.saveGState(); tile.addClip()
NSGradient(colors: [rgb(0xB9AEFF, 0.55), rgb(0xB9AEFF, 0)], atLocations: [0, 1], colorSpace: .sRGB)!
    .draw(in: NSBezierPath(ovalIn: R(150, 560, 724, 560)), relativeCenterPosition: NSPoint(x: 0, y: 0.2))
ctx.restoreGState()

// A and Я on two tiles, diagonal, with a cycle of two arrows: switch between alphabets.
let a = NSBezierPath(roundedRect: R(200, 470, 330, 330), xRadius: 84 * s, yRadius: 84 * s)
rgb(0xFFFFFF, 0.26).setFill(); a.fill(); rgb(0xFFFFFF, 0.6).setStroke(); a.lineWidth = 4 * s; a.stroke()
glyph("A", rounded(230, .bold), rgb(0xFFFFFF), cx: 365, cy: 635, shadow: false)
let ya = NSBezierPath(roundedRect: R(494, 224, 330, 330), xRadius: 84 * s, yRadius: 84 * s)
ctx.saveGState(); ctx.setShadow(offset: CGSize(width: 0, height: -16 * s), blur: 40 * s, color: rgb(0x14093D, 0.45).cgColor)
rgb(0xFFFFFF).setFill(); ya.fill(); ctx.restoreGState()
glyph("Я", rounded(240, .heavy), rgb(violet), cx: 659, cy: 389, shadow: false)
if !small {
    func arrow(_ from: NSPoint, _ ctrl: NSPoint, _ to: NSPoint, _ headDir: (CGFloat, CGFloat)) {
        let p = NSBezierPath(); p.move(to: from); p.curve(to: to, controlPoint1: ctrl, controlPoint2: ctrl)
        roundedLine(p, rgb(0xFFFFFF, 0.9), 22)
        let (dx, dy) = headDir, l: CGFloat = 46 * s
        let h = NSBezierPath()
        h.move(to: NSPoint(x: to.x - l * dx + l * 0.7 * dy, y: to.y - l * dy - l * 0.7 * dx))
        h.line(to: to)
        h.line(to: NSPoint(x: to.x - l * dx - l * 0.7 * dy, y: to.y - l * dy + l * 0.7 * dx))
        roundedLine(h, rgb(0xFFFFFF, 0.9), 22)
    }
    // top-right: from A's tile over to Я's; bottom-left: back again
    arrow(NSPoint(x: 600 * s, y: 760 * s), NSPoint(x: 790 * s, y: 760 * s), NSPoint(x: 790 * s, y: 610 * s), (0, -1))
    arrow(NSPoint(x: 424 * s, y: 264 * s), NSPoint(x: 234 * s, y: 264 * s), NSPoint(x: 234 * s, y: 414 * s), (0, 1))
}

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
