// Draws the background of Mistype's disk image window: Mistype on the left, Applications on the right,
// an arrow between them and a one-line instruction. Run: swift tools/dmg-background.swift <out.png> [scale]
// The window is 640×400 points; pass scale 2 for the @2x (Retina) version.
import AppKit

let args = CommandLine.arguments
let out = args[1]
let scale = CGFloat(Double(args.count > 2 ? args[2] : "1") ?? 1)
let W: CGFloat = 640, H: CGFloat = 400

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W * scale), pixelsHigh: Int(H * scale),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: W, height: H)  // points, so the @2x image draws at the same size
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

func rgb(_ hex: Int, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: a)
}

// Light background with a faint violet wash at the top, so Finder's black icon labels stay readable.
NSGradient(colors: [rgb(0xF1EEFF), rgb(0xFFFFFF)], atLocations: [0, 1], colorSpace: .sRGB)!
    .draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -90)

// Arrow between the two icon spots (Finder places the icons at x 160 and 480, y 190 from the top).
let y: CGFloat = H - 190
let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 262, y: y)); arrow.line(to: NSPoint(x: 372, y: y))
arrow.move(to: NSPoint(x: 352, y: y + 18)); arrow.line(to: NSPoint(x: 374, y: y)); arrow.line(to: NSPoint(x: 352, y: y - 18))
rgb(0x5B4BF0).setStroke(); arrow.lineWidth = 6; arrow.lineCapStyle = .round; arrow.lineJoinStyle = .round; arrow.stroke()

func centered(_ text: String, _ size: CGFloat, _ weight: NSFont.Weight, _ color: NSColor, top: CGFloat) {
    let font = NSFont(descriptor: NSFont.systemFont(ofSize: size, weight: weight).fontDescriptor.withDesign(.rounded)!, size: size)!
    let str = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
    let b = str.size()
    str.draw(at: NSPoint(x: (W - b.width) / 2, y: H - top - b.height))
}
centered("Перетащите Mistype в «Программы»", 20, .semibold, rgb(0x1F1A3D), top: 40)
centered("Drag Mistype to Applications", 14, .regular, rgb(0x4A4560), top: 70)
centered("Потом откройте Mistype из «Программ» · Then open it from Applications", 12, .regular, rgb(0x4A4560), top: 340)

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
