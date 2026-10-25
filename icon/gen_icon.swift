import AppKit
import Foundation

// Generate the macOS-style app icon for Janus, at 1024 px and every size of the iconset.
// Monochrome, in the style of Thoth: black rounded square, white Janus symbol J2
// (mark 1.3, brand/svg/janus-symbol-*.svg). Same path as Sources/Janus/Views/JanusMark.swift.
// Each size is drawn from the vector (no resampling, no metadata added by other tools).
//
// Regenerate the app icon (from app/):
//   swift icon/gen_icon.swift Sources/Janus/Resources/Assets.xcassets/AppIcon.appiconset

func renderIcon(size: Int) -> Data? {
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
          let gc = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
    let ctx = gc.cgContext
    let side = CGFloat(size)

    // macOS Big Sur squircle has corner radius ~22.37% of side, with 10% padding on the canvas.
    let pad = side * 0.10
    let rect = CGRect(x: pad, y: pad, width: side - 2*pad, height: side - 2*pad)
    let radius = rect.width * 0.2237

    ctx.clear(CGRect(x: 0, y: 0, width: side, height: side))
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
    ctx.fillPath()

    // Symbol J2 on its 64 × 64 grid (y down), 5-unit stroke, round caps and joins:
    // `M18 50.5V44M18 35.6V27.5A14 14 0 0 1 46 27.5V35.6M46 44V50.5`.
    // Its ink (caps included) spans x 15.5–48.5, y 11–53, centred on (32, 32).
    // The grid is drawn at the same scale as Thoth's icon, so both strokes match.
    let scale = rect.height * 0.58 / 47

    ctx.saveGState()
    // Centre the grid on the square and flip to its y-down axis.
    ctx.translateBy(x: rect.midX, y: rect.midY)
    ctx.scaleBy(x: scale, y: -scale)
    ctx.translateBy(x: -32, y: -32)
    ctx.move(to: CGPoint(x: 18, y: 50.5))
    ctx.addLine(to: CGPoint(x: 18, y: 44))
    ctx.move(to: CGPoint(x: 18, y: 35.6))
    ctx.addLine(to: CGPoint(x: 18, y: 27.5))
    // Half circle over the top of the arch (centre (32, 27.5), increasing y-down angle).
    ctx.addArc(center: CGPoint(x: 32, y: 27.5), radius: 14, startAngle: .pi, endAngle: 2 * .pi, clockwise: false)
    ctx.addLine(to: CGPoint(x: 46, y: 35.6))
    ctx.move(to: CGPoint(x: 46, y: 44))
    ctx.addLine(to: CGPoint(x: 46, y: 50.5))
    ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
    ctx.setLineWidth(5)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.strokePath()
    ctx.restoreGState()

    return rep.representation(using: .png, properties: [:])
}

// File names of AppIcon.appiconset (see its Contents.json).
let outputs: [(name: String, size: Int)] = [
    ("icon_16.png", 16), ("icon_32.png", 32), ("icon_32@2x.png", 64), ("icon_128.png", 128),
    ("icon_256.png", 256), ("icon_512.png", 512), ("icon_1024.png", 1024),
]
let dir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
for (name, size) in outputs {
    guard let png = renderIcon(size: size) else {
        fputs("Failed to render \(name)\n", stderr); exit(1)
    }
    let url = dir.appendingPathComponent(name)
    try png.write(to: url)
    print("Wrote \(url.path)")
}
