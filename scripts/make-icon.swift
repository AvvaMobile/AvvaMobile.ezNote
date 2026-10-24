// Uygulama simgesini üretir: swift scripts/make-icon.swift <çıktı.iconset>
// Mavi zemin üstünde beyaz, spiralli ve çizgili bir not kâğıdı ile çapraz bir kalem.
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

    // Simge tek renk beyaz; ayrıntılar zeminin mavisiyle "oyulur".
    let white = rgb(255, 255, 255)
    let cut = rgb(58, 132, 228)

    // Kâğıt
    let paper = NSRect(x: 262, y: 190, width: 500, height: 600)
    white.setFill()
    NSBezierPath(roundedRect: paper, xRadius: 36, yRadius: 36).fill()

    // Üst şeridi kâğıttan ayıran boşluk
    cut.setFill()
    NSBezierPath(rect: NSRect(x: paper.minX, y: paper.maxY - 118, width: paper.width, height: 14)).fill()

    // Çizgiler
    for i in 0..<5 {
        NSBezierPath(roundedRect: NSRect(x: paper.minX + 60, y: paper.maxY - 200 - CGFloat(i) * 78, width: paper.width - 120, height: 14),
                     xRadius: 7, yRadius: 7).fill()
    }

    // Spiral halkalar: kâğıttaki delik mavi, halka beyaz ve mavi çerçeveli
    for i in 0..<5 {
        let x = paper.minX + 80 + CGFloat(i) * 85
        cut.setFill()
        NSBezierPath(ovalIn: NSRect(x: x - 15, y: paper.maxY - 70, width: 30, height: 30)).fill()
        let ring = NSBezierPath(roundedRect: NSRect(x: x - 11, y: paper.maxY - 56, width: 22, height: 100), xRadius: 11, yRadius: 11)
        cut.setStroke()
        ring.lineWidth = 12
        ring.stroke()
        white.setFill()
        ring.fill()
    }

    // Kalem: sağ altta, 45 derece; kâğıttan ayrılsın diye kalın mavi çerçeve
    NSGraphicsContext.saveGraphicsState()
    let t = NSAffineTransform()
    t.translateX(by: 700, yBy: 300)
    t.rotate(byDegrees: 135)
    t.concat()
    let w: CGFloat = 78
    let pencil = NSBezierPath()
    pencil.move(to: NSPoint(x: -100, y: 0))
    pencil.line(to: NSPoint(x: 0, y: -w / 2))
    pencil.line(to: NSPoint(x: 400, y: -w / 2))
    pencil.appendArc(withCenter: NSPoint(x: 400, y: 0), radius: w / 2, startAngle: -90, endAngle: 90)
    pencil.line(to: NSPoint(x: 0, y: w / 2))
    pencil.close()
    cut.setStroke()
    pencil.lineWidth = 28
    pencil.lineJoinStyle = .round
    pencil.stroke()
    white.setFill()
    pencil.fill()
    // Uç ile gövde ve gövde ile silgi arasındaki ayrım çizgileri
    cut.setFill()
    NSBezierPath(rect: NSRect(x: -4, y: -w / 2, width: 12, height: w)).fill()
    NSBezierPath(rect: NSRect(x: 330, y: -w / 2, width: 12, height: w)).fill()
    let lead = NSBezierPath()
    lead.move(to: NSPoint(x: -62, y: -15))
    lead.line(to: NSPoint(x: -100, y: 0))
    lead.line(to: NSPoint(x: -62, y: 15))
    lead.close()
    lead.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    try render(base).write(to: output.appendingPathComponent("icon_\(base)x\(base).png"))
    try render(base * 2).write(to: output.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
