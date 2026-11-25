// Draws the app icon as a 1024px PNG.
//   swift assets/icon.swift <stack|install|ember> <out.png>
import AppKit

let args = CommandLine.arguments
let variant = args.count > 1 ? args[1] : "install"
let out = args.count > 2 ? args[2] : "icon.png"

let size: CGFloat = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
  NSColor(srgbRed: CGFloat(hex >> 16 & 0xff) / 255, green: CGFloat(hex >> 8 & 0xff) / 255,
          blue: CGFloat(hex & 0xff) / 255, alpha: a)
}

// macOS icon grid: 824px rounded square inside the 1024 canvas.
let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let squircle = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.45).cgColor)
rgb(0x000000).setFill()
squircle.fill()
ctx.restoreGState()

squircle.addClip()
let bg: NSGradient = switch variant {
case "ember": NSGradient(starting: rgb(0xB3261E), ending: rgb(0x1A0503))!
case "stack": NSGradient(starting: rgb(0x161616), ending: rgb(0x000000))!
default:      NSGradient(starting: rgb(0x1B2A4A), ending: rgb(0x000000))!
}
bg.draw(in: body, angle: -90)
rgb(0xFFFFFF, 0.10).setStroke()
let rim = NSBezierPath(roundedRect: body.insetBy(dx: 2, dy: 2), xRadius: 183, yRadius: 183)
rim.lineWidth = 4
rim.stroke()

// Database cylinder: one solid body split into three discs by dark seams.
let cx: CGFloat = variant == "install" ? 470 : 512
let w: CGFloat = 400, rx = w / 2, ry: CGFloat = 62
let bottom: CGFloat = 290, height: CGFloat = 420
let seam: NSColor = switch variant {
case "ember": rgb(0x5A120D)
case "stack": rgb(0x0A0A0A)
default:      rgb(0x0F1A30)
}
let bodyPath = NSBezierPath(ovalIn: NSRect(x: cx - rx, y: bottom - ry, width: w, height: ry * 2))
bodyPath.append(NSBezierPath(rect: NSRect(x: cx - rx, y: bottom, width: w, height: height)))
rgb(0xFFFFFF).setFill()
bodyPath.fill()
NSGraphicsContext.saveGraphicsState()
bodyPath.addClip()
for i in 1...2 {
  // Front half of an ellipse: the visible edge of the disc above.
  let y = bottom + height * CGFloat(i) / 3
  let arc = NSBezierPath()
  arc.appendArc(withCenter: .zero, radius: 1, startAngle: 180, endAngle: 360)
  arc.transform(using: AffineTransform(scaleByX: rx, byY: ry))
  arc.transform(using: AffineTransform(translationByX: cx, byY: y))
  arc.lineWidth = 22
  seam.setStroke()
  arc.stroke()
}
NSGraphicsContext.restoreGraphicsState()
let top = NSBezierPath(ovalIn: NSRect(x: cx - rx, y: bottom + height - ry, width: w, height: ry * 2))
rgb(0xC9D1DE).setFill()
top.fill()

if variant == "install" {
  // Download badge: circle with a down arrow, bottom right.
  let c = NSPoint(x: 690, y: 330), r: CGFloat = 128
  let ring = NSBezierPath(ovalIn: NSRect(x: c.x - r - 14, y: c.y - r - 14, width: (r + 14) * 2, height: (r + 14) * 2))
  rgb(0x0B1220).setFill(); ring.fill()
  let dot = NSBezierPath(ovalIn: NSRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
  rgb(0x3B82F6).setFill(); dot.fill()
  let arrow = NSBezierPath()
  arrow.lineWidth = 30; arrow.lineCapStyle = .round; arrow.lineJoinStyle = .round
  arrow.move(to: NSPoint(x: c.x, y: c.y + 62)); arrow.line(to: NSPoint(x: c.x, y: c.y - 52))
  arrow.move(to: NSPoint(x: c.x - 52, y: c.y)); arrow.line(to: NSPoint(x: c.x, y: c.y - 52))
  arrow.line(to: NSPoint(x: c.x + 52, y: c.y))
  rgb(0xFFFFFF).setStroke(); arrow.stroke()
}

NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
