import Foundation
import AppKit

func renderIcon(size: Int) -> NSImage {
    let s = CGFloat(size)
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()

    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    // Outer padding for macOS squircle
    let inset = s * 0.1
    let rect = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let cornerRadius = rect.width * 0.224 // Apple standard continuous corner ratio
    let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)

    // Shadow
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.04)
    shadow.shadowBlurRadius = s * 0.08
    shadow.set()

    // Background Gradient: Deep Night Sky to Electric Nebula
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let colors = [
        NSColor(red: 0.06, green: 0.09, blue: 0.22, alpha: 1.0).cgColor,
        NSColor(red: 0.12, green: 0.28, blue: 0.65, alpha: 1.0).cgColor,
        NSColor(red: 0.45, green: 0.20, blue: 0.75, alpha: 1.0).cgColor
    ] as CFArray

    if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 0.6, 1.0]) {
        ctx.saveGState()
        path.addClip()
        ctx.drawLinearGradient(gradient, start: CGPoint(x: rect.midX, y: rect.maxY), end: CGPoint(x: rect.midX, y: rect.minY), options: [])
        ctx.restoreGState()
    }

    // Border glow
    NSColor.white.withAlphaComponent(0.15).setStroke()
    path.lineWidth = s * 0.015
    path.stroke()

    // Inner icon symbol: Draw a stylized vacuum / cosmic sparkle burst
    let center = CGPoint(x: rect.midX, y: rect.midY)

    // Sparkle star in center
    ctx.saveGState()
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.setShadow(offset: .zero, blur: s * 0.05, color: NSColor.cyan.withAlphaComponent(0.8).cgColor)

    let starSize = s * 0.32
    let starRect = CGRect(x: center.x - starSize/2, y: center.y - starSize/2 + s*0.02, width: starSize, height: starSize)

    // Draw 4-point sparkle star
    let starPath = NSBezierPath()
    let cx = starRect.midX
    let cy = starRect.midY
    let r1 = starSize * 0.5
    let r2 = starSize * 0.14

    starPath.move(to: NSPoint(x: cx, y: cy + r1))
    starPath.curve(to: NSPoint(x: cx + r1, y: cy), controlPoint1: NSPoint(x: cx + r2, y: cy + r2), controlPoint2: NSPoint(x: cx + r2, y: cy + r2))
    starPath.curve(to: NSPoint(x: cx, y: cy - r1), controlPoint1: NSPoint(x: cx + r2, y: cy - r2), controlPoint2: NSPoint(x: cx + r2, y: cy - r2))
    starPath.curve(to: NSPoint(x: cx - r1, y: cy), controlPoint1: NSPoint(x: cx - r2, y: cy - r2), controlPoint2: NSPoint(x: cx - r2, y: cy - r2))
    starPath.curve(to: NSPoint(x: cx, y: cy + r1), controlPoint1: NSPoint(x: cx - r2, y: cy + r2), controlPoint2: NSPoint(x: cx - r2, y: cy + r2))
    starPath.close()
    starPath.fill()

    // Small satellite sparkles
    let s2 = starSize * 0.3
    let s2Rect = CGRect(x: cx + r1 * 0.6, y: cy + r1 * 0.5, width: s2, height: s2)
    let p2 = NSBezierPath()
    p2.move(to: NSPoint(x: s2Rect.midX, y: s2Rect.maxY))
    p2.curve(to: NSPoint(x: s2Rect.maxX, y: s2Rect.midY), controlPoint1: NSPoint(x: s2Rect.midX + s2*0.1, y: s2Rect.midY + s2*0.1), controlPoint2: NSPoint(x: s2Rect.midX + s2*0.1, y: s2Rect.midY + s2*0.1))
    p2.curve(to: NSPoint(x: s2Rect.midX, y: s2Rect.minY), controlPoint1: NSPoint(x: s2Rect.midX + s2*0.1, y: s2Rect.midY - s2*0.1), controlPoint2: NSPoint(x: s2Rect.midX + s2*0.1, y: s2Rect.midY - s2*0.1))
    p2.curve(to: NSPoint(x: s2Rect.minX, y: s2Rect.midY), controlPoint1: NSPoint(x: s2Rect.midX - s2*0.1, y: s2Rect.midY - s2*0.1), controlPoint2: NSPoint(x: s2Rect.midX - s2*0.1, y: s2Rect.midY - s2*0.1))
    p2.curve(to: NSPoint(x: s2Rect.midX, y: s2Rect.maxY), controlPoint1: NSPoint(x: s2Rect.midX - s2*0.1, y: s2Rect.midY + s2*0.1), controlPoint2: NSPoint(x: s2Rect.midX - s2*0.1, y: s2Rect.midY + s2*0.1))
    p2.close()
    p2.fill()

    // Disk Reclaimer sweep ring arc
    let arcPath = NSBezierPath()
    arcPath.appendArc(withCenter: NSPoint(x: center.x, y: center.y - s * 0.04), radius: s * 0.28, startAngle: 200, endAngle: 340)
    NSColor(red: 0.3, green: 0.8, blue: 1.0, alpha: 0.9).setStroke()
    arcPath.lineWidth = s * 0.04
    arcPath.lineCapStyle = .round
    arcPath.stroke()

    ctx.restoreGState()

    image.unlockFocus()
    return image
}

func savePNG(image: NSImage, path: String) {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { return }
    try? png.write(to: URL(fileURLWithPath: path))
}

let iconsetDir = "/tmp/NovaSweep.iconset"
try? FileManager.default.removeItem(atPath: iconsetDir)
try? FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

let sizes = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, size) in sizes {
    let img = renderIcon(size: size)
    savePNG(image: img, path: "\(iconsetDir)/\(name)")
}

print("Iconset created at \(iconsetDir)")
