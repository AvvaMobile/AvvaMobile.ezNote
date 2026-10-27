// Uygulama simgesini üretir: swift scripts/make-icon.swift <çıktı.iconset>
// Beyaz zemin üstünde mavi, spiralli ve çizgili bir not kâğıdı.
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
    NSGradient(starting: rgb(255, 255, 255), ending: rgb(242, 244, 248))!.draw(in: bodyPath, angle: -90)

    // Simge tek renk mavi; ayrıntılar zeminin beyazıyla "oyulur".
    let blue = rgb(58, 132, 228)
    let cut = rgb(250, 251, 253)

    // Kâğıt: halkalarla birlikte zeminin tam ortasında, her yandan geniş boşluk
    let ringOverhang: CGFloat = 44
    let paperSize = NSSize(width: 420, height: 470)
    let paper = NSRect(x: (1024 - paperSize.width) / 2, y: (1024 - paperSize.height - ringOverhang) / 2,
                       width: paperSize.width, height: paperSize.height)
    NSGradient(starting: rgb(98, 178, 247), ending: rgb(38, 104, 214))!
        .draw(in: NSBezierPath(roundedRect: paper, xRadius: 34, yRadius: 34), angle: -90)

    // Üst şeridi kâğıttan ayıran boşluk
    cut.setFill()
    NSBezierPath(rect: NSRect(x: paper.minX, y: paper.maxY - 100, width: paper.width, height: 12)).fill()

    // Çizgiler
    for i in 0..<5 {
        NSBezierPath(roundedRect: NSRect(x: paper.minX + 50, y: paper.maxY - 170 - CGFloat(i) * 62, width: paper.width - 100, height: 13),
                     xRadius: 6.5, yRadius: 6.5).fill()
    }

    // Spiral halkalar: kâğıttaki delik beyaz, halka mavi ve beyaz çerçeveli
    for i in 0..<5 {
        let x = paper.minX + 62 + CGFloat(i) * 74
        cut.setFill()
        NSBezierPath(ovalIn: NSRect(x: x - 14, y: paper.maxY - 64, width: 28, height: 28)).fill()
        let ring = NSBezierPath(roundedRect: NSRect(x: x - 10, y: paper.maxY - 52, width: 20, height: 52 + ringOverhang), xRadius: 10, yRadius: 10)
        cut.setStroke()
        ring.lineWidth = 11
        ring.stroke()
        blue.setFill()
        ring.fill()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    try render(base).write(to: output.appendingPathComponent("icon_\(base)x\(base).png"))
    try render(base * 2).write(to: output.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
