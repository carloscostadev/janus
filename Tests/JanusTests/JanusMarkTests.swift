import AppKit
import Testing
@testable import Janus

/// Geometry of the mark 1.3 paths against the boxes of svg/janus-*.svg.
struct JanusMarkTests {
    static func isClose(_ a: CGRect, _ b: CGRect, tolerance: CGFloat = 0.01) -> Bool {
        abs(a.minX - b.minX) < tolerance && abs(a.minY - b.minY) < tolerance
            && abs(a.width - b.width) < tolerance && abs(a.height - b.height) < tolerance
    }

    @Test func symbolInkMatchesInkRect() {
        let ink = JanusMark.centerline.copy(strokingWithWidth: JanusMark.strokeWidth,
                                            lineCap: .round, lineJoin: .round, miterLimit: 10)
        #expect(Self.isClose(ink.boundingBoxOfPath, JanusMark.inkRect))
        // Centred on the 64-unit grid.
        #expect(abs(JanusMark.inkRect.midX - 32) < 0.01 && abs(JanusMark.inkRect.midY - 32) < 0.01)
    }

    @Test func wordmarkSpansItsGrid() {
        // viewBox "0 -0.6 205 41.2": ink from y 0 to 40.6 (the U's outer arc).
        #expect(Self.isClose(JanusMark.wordmark.boundingBoxOfPath, CGRect(x: 0, y: 0, width: 205, height: 40.6)))
    }

    @Test func lockupInkMatchesSvg() {
        // viewBox "15.5 0 172 64": the scaled wordmark ends at x 187.5.
        let right = JanusMark.wordmarkOrigin.x + 205 * JanusMark.wordmarkScale
        #expect(abs(right - JanusMark.lockupInkRect.maxX) < 0.01)
        #expect(JanusMark.lockupInkRect.minY == JanusMark.inkRect.minY)
        #expect(JanusMark.lockupInkRect.height == JanusMark.inkRect.height)
    }

    @Test func menuBarImageIsTemplate() {
        let image = JanusMark.menuBarImage
        #expect(image.isTemplate)
        #expect(image.size == NSSize(width: 13, height: 18))
        // The ink spans the canvas width and fits its height below the 1 pt top margin.
        let inkHeight = image.size.width * JanusMark.inkRect.height / JanusMark.inkRect.width
        #expect(inkHeight >= 16 && 1 + inkHeight <= image.size.height)
    }
}
