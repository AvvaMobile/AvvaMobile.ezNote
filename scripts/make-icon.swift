// Uygulama simgesini üretir: swift scripts/make-icon.swift <çıktı.iconset>
// Mavi zemin üstünde spiralli, çizgili bir not kâğıdı ve çapraz bir kalem.
import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(red: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

func render(_ pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    // Tüm çizim 1024'lük tuval üzerinden ölçeklenir.
    let scale = CGFloat(pixels) / 1024
    NSAffineTransform(transform: { let t = AffineTransform(scale: scale); return t }()).concat()

    // Zemin
    let body = NSRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)
    NSGradient(starting: rgb(98, 178, 247), ending: rgb(38, 104, 214))!.draw(in: bodyPath, angle: -90)

    // Kâğıt ve gölgesi
    let paper = NSRect(x: 262, y: 190, width: 500, height: 600)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = rgb(10, 40, 100, 0.35)
    shadow.shadowBlurRadius = 30
    shadow.shadowOffset = NSSize(width: 0, height: -14)
    shadow.set()
    rgb(255, 255, 255).setFill()
    NSBezierPath(roundedRect: paper, xRadius: 28, yRadius: 28).fill()
    NSGraphicsContext.restoreGraphicsState()

    // Üst şerit
    let header = NSBezierPath(roundedRect: NSRect(x: paper.minX, y: paper.maxY - 110, width: paper.width, height: 110), xRadius: 28, yRadius: 28)
    header.append(NSBezierPath(rect: NSRect(x: paper.minX, y: paper.maxY - 110, width: paper.width, height: 40)))
    rgb(255, 196, 61).setFill()
    header.fill()

    // Çizgiler ve kenar boşluğu çizgisi
    rgb(150, 190, 235).setFill()
    for i in 0..<6 {
        NSBezierPath(rect: NSRect(x: paper.minX + 40, y: paper.maxY - 190 - CGFloat(i) * 72, width: paper.width - 80, height: 9)).fill()
    }
    rgb(240, 110, 110).setFill()
    NSBezierPath(rect: NSRect(x: paper.minX + 92, y: paper.minY + 30, width: 7, height: paper.height - 170)).fill()

    // Spiral halkalar
    for i in 0..<5 {
        let x = paper.minX + 80 + CGFloat(i) * 85
        rgb(60, 70, 90).setFill()
        NSBezierPath(ovalIn: NSRect(x: x - 16, y: paper.maxY - 72, width: 32, height: 32)).fill()
        let ring = NSBezierPath(roundedRect: NSRect(x: x - 9, y: paper.maxY - 58, width: 18, height: 96), xRadius: 9, yRadius: 9)
        rgb(205, 212, 225).setFill()
        ring.fill()
        rgb(140, 150, 170).setStroke()
        ring.lineWidth = 4
        ring.stroke()
    }

    // Kalem: sağ altta, 45 derece
    NSGraphicsContext.saveGraphicsState()
    let t = NSAffineTransform()
    t.translateX(by: 700, yBy: 300)
    t.rotate(byDegrees: 135)
    t.concat()
    let w: CGFloat = 70
    rgb(255, 170, 40).setFill()
    NSBezierPath(rect: NSRect(x: 0, y: -w / 2, width: 330, height: w)).fill()
    rgb(235, 140, 20).setFill()
    NSBezierPath(rect: NSRect(x: 0, y: -w / 2, width: 330, height: w / 3)).fill()
    rgb(200, 205, 215).setFill()
    NSBezierPath(rect: NSRect(x: 330, y: -w / 2, width: 40, height: w)).fill()
    rgb(250, 140, 150).setFill()
    NSBezierPath(roundedRect: NSRect(x: 360, y: -w / 2, width: 60, height: w), xRadius: 18, yRadius: 18).fill()
    let tip = NSBezierPath()
    tip.move(to: NSPoint(x: 0, y: -w / 2))
    tip.line(to: NSPoint(x: -95, y: 0))
    tip.line(to: NSPoint(x: 0, y: w / 2))
    tip.close()
    rgb(245, 215, 170).setFill()
    tip.fill()
    let lead = NSBezierPath()
    lead.move(to: NSPoint(x: -62, y: -12))
    lead.line(to: NSPoint(x: -95, y: 0))
    lead.line(to: NSPoint(x: -62, y: 12))
    lead.close()
    rgb(50, 55, 65).setFill()
    lead.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    try render(base).write(to: output.appendingPathComponent("icon_\(base)x\(base).png"))
    try render(base * 2).write(to: output.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
