import AppKit
import SwiftUI

/// Janus mark 1.3 (brand/): symbol J2 "passage", a doorway arch on a
/// 64 × 64 grid, 5-unit stroke, round caps and joins, both pillars cut by the
/// horizon. Drawn in code so the app bundle needs no resources. Path copied from
/// brand/svg/janus-symbol-*.svg: `M18 50.5V44M18 35.6V27.5A14 14 0 0 1 46 27.5V35.6M46 44V50.5`.
enum JanusMark {
    /// Inked area on the 64-unit grid, round caps included (y down).
    static let inkRect = CGRect(x: 15.5, y: 11, width: 33, height: 42)
    static let strokeWidth: CGFloat = 5

    /// Centre line of the symbol in grid units (y down).
    static let centerline: CGPath = {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 18, y: 50.5))
        path.addLine(to: CGPoint(x: 18, y: 44))
        path.move(to: CGPoint(x: 18, y: 35.6))
        path.addLine(to: CGPoint(x: 18, y: 27.5))
        addArc(to: path, to: CGPoint(x: 46, y: 27.5), radius: 14, sweep: true)
        path.addLine(to: CGPoint(x: 46, y: 35.6))
        path.move(to: CGPoint(x: 46, y: 44))
        path.addLine(to: CGPoint(x: 46, y: 50.5))
        return path
    }()

    /// JANUS wordmark on its W1-H grid (205 × 40.6 units, y down), copied from
    /// brand/svg/janus-wordmark-*.svg: straight strokes as polygons, the curves as circle
    /// arcs; J, A and N are cut by the same horizontal gap between y 24.5 and 27.9.
    static let wordmark: CGPath = {
        let path = CGMutablePath()
        func polygon(_ points: [(CGFloat, CGFloat)]) {
            path.addLines(between: points.map { CGPoint(x: $0.0, y: $0.1) })
            path.closeSubpath()
        }
        // J: stem, then the hook (outer arc under the bottom, inner arc back).
        path.addRect(CGRect(x: 19.2, y: 0, width: 5, height: 24.5))
        path.move(to: CGPoint(x: 24.2, y: 27.9))
        addArc(to: path, to: CGPoint(x: 0, y: 27.9), radius: 12.1, sweep: true)
        path.addLine(to: CGPoint(x: 5, y: 27.9))
        addArc(to: path, to: CGPoint(x: 19.2, y: 27.9), radius: 7.1, sweep: false)
        path.closeSubpath()
        // A: apex above the gap, two legs below it.
        polygon([(45.27, 0), (50.73, 0), (60.08, 24.5), (54.62, 24.5), (48, 7.15), (41.38, 24.5), (35.92, 24.5)])
        polygon([(34.62, 27.9), (40.08, 27.9), (35.46, 40), (30, 40)])
        polygon([(55.92, 27.9), (61.38, 27.9), (66, 40), (60.54, 40)])
        // N: two stems and the diagonal, each in two parts.
        for x in [74, 102] as [CGFloat] {
            path.addRect(CGRect(x: x, y: 0, width: 5, height: 24.5))
            path.addRect(CGRect(x: x, y: 27.9, width: 5, height: 12.1))
        }
        polygon([(74, 0), (80.5, 0), (96.73, 24.5), (90.23, 24.5)])
        polygon([(92.48, 27.9), (98.98, 27.9), (107, 40), (100.5, 40)])
        // U: one band, inner edge down and outer edge back up.
        path.move(to: CGPoint(x: 123, y: 0))
        path.addLine(to: CGPoint(x: 123, y: 21.1))
        addArc(to: path, to: CGPoint(x: 137.5, y: 35.6), radius: 14.5, sweep: false)
        addArc(to: path, to: CGPoint(x: 152, y: 21.1), radius: 14.5, sweep: false)
        path.addLine(to: CGPoint(x: 152, y: 0))
        path.addLine(to: CGPoint(x: 157, y: 0))
        path.addLine(to: CGPoint(x: 157, y: 21.1))
        addArc(to: path, to: CGPoint(x: 137.5, y: 40.6), radius: 19.5, sweep: true)
        addArc(to: path, to: CGPoint(x: 118, y: 21.1), radius: 19.5, sweep: true)
        path.addLine(to: CGPoint(x: 118, y: 0))
        path.closeSubpath()
        // S: one band from the top-right end to the bottom-left end and back.
        path.move(to: CGPoint(x: 204, y: 5))
        path.addLine(to: CGPoint(x: 179.25, y: 5))
        addArc(to: path, to: CGPoint(x: 173, y: 11.25), radius: 6.25, sweep: false)
        addArc(to: path, to: CGPoint(x: 179.25, y: 17.5), radius: 6.25, sweep: false)
        path.addLine(to: CGPoint(x: 193.75, y: 17.5))
        addArc(to: path, to: CGPoint(x: 205, y: 28.75), radius: 11.25, sweep: true)
        addArc(to: path, to: CGPoint(x: 193.75, y: 40), radius: 11.25, sweep: true)
        path.addLine(to: CGPoint(x: 169, y: 40))
        path.addLine(to: CGPoint(x: 169, y: 35))
        path.addLine(to: CGPoint(x: 193.75, y: 35))
        addArc(to: path, to: CGPoint(x: 200, y: 28.75), radius: 6.25, sweep: false)
        addArc(to: path, to: CGPoint(x: 193.75, y: 22.5), radius: 6.25, sweep: false)
        path.addLine(to: CGPoint(x: 179.25, y: 22.5))
        addArc(to: path, to: CGPoint(x: 168, y: 11.25), radius: 11.25, sweep: true)
        addArc(to: path, to: CGPoint(x: 179.25, y: 0), radius: 11.25, sweep: true)
        path.addLine(to: CGPoint(x: 204, y: 0))
        path.closeSubpath()
        return path
    }()

    /// Lockup as in brand/svg/janus-lockup-*.svg: wordmark at 60% scale, origin (64.5, 20) on
    /// the symbol's grid. Inked area, round caps included.
    static let lockupInkRect = CGRect(x: 15.5, y: 11, width: 172, height: 42)
    static let wordmarkOrigin = CGPoint(x: 64.5, y: 20)
    static let wordmarkScale: CGFloat = 0.6

    /// Size of the menu bar image, in points.
    static let menuBarCanvas = NSSize(width: 13, height: 18)

    /// SVG arc (`A r r 0 0 sweep x y`, small arc) from the current point to `end`.
    /// `sweep` follows the SVG flag: true is the increasing y-down angle direction.
    private static func addArc(to path: CGMutablePath, to end: CGPoint, radius: CGFloat, sweep: Bool) {
        let start = path.currentPoint
        let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        let half = CGPoint(x: (start.x - end.x) / 2, y: (start.y - end.y) / 2)
        let halfSquared = half.x * half.x + half.y * half.y
        // Centre offset from the chord's midpoint, on the side the small arc needs.
        let k = (max(0, radius * radius - halfSquared) / halfSquared).squareRoot() * (sweep ? 1 : -1)
        let center = CGPoint(x: mid.x + k * half.y, y: mid.y - k * half.x)
        path.addArc(center: center, radius: radius,
                    startAngle: atan2(start.y - center.y, start.x - center.x),
                    endAngle: atan2(end.y - center.y, end.x - center.x),
                    clockwise: !sweep)
    }

    /// Menu bar icon: template image (follows the light/dark menu bar and the
    /// highlight), 13 pt wide and 16.5 pt high of ink (2 pt stroke) in a 13 × 18 pt
    /// canvas. Drawn by a handler at the backing scale, so it is sharp at 1x and 2x.
    /// Both pillars' edges and the top of the arch sit on (almost) whole points.
    static let menuBarImage: NSImage = {
        let scale = menuBarCanvas.width / inkRect.width
        let image = NSImage(size: menuBarCanvas, flipped: true) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.translateBy(x: 0, y: 1)
            draw(in: ctx, scale: scale, color: CGColor(gray: 0, alpha: 1))
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Janus"
        return image
    }()

    /// Strokes the mark with its ink box at the context origin (context must be y-down).
    static func draw(in ctx: CGContext, scale: CGFloat, color: CGColor) {
        ctx.saveGState()
        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: -inkRect.minX, y: -inkRect.minY)
        ctx.addPath(centerline)
        ctx.setStrokeColor(color)
        ctx.setLineWidth(strokeWidth)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.strokePath()
        ctx.restoreGState()
    }
}

/// The Janus lockup (symbol + JANUS wordmark), in the current foreground style;
/// `height` is the symbol's visible height.
struct JanusLockup: View {
    var height: CGFloat

    var body: some View {
        let ink = JanusMark.lockupInkRect
        let scale = height / ink.height
        // The ink touches the box on every side (round caps, the S). Draw into a canvas
        // 2 units larger all round and take that margin back out of the layout, so the
        // canvas never clips the anti-aliased edges.
        let margin = 2 * scale
        Canvas { context, _ in
            context.translateBy(x: margin, y: margin)
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -ink.minX, y: -ink.minY)
            context.stroke(Path(JanusMark.centerline), with: .foreground,
                           style: StrokeStyle(lineWidth: JanusMark.strokeWidth, lineCap: .round, lineJoin: .round))
            context.translateBy(x: JanusMark.wordmarkOrigin.x, y: JanusMark.wordmarkOrigin.y)
            context.scaleBy(x: JanusMark.wordmarkScale, y: JanusMark.wordmarkScale)
            context.fill(Path(JanusMark.wordmark), with: .foreground)
        }
        .frame(width: ink.width * scale + 2 * margin, height: height + 2 * margin)
        .padding(-margin)
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: "Janus"))
    }
}
