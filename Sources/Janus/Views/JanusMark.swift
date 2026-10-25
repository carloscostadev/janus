import SwiftUI

/// Janus symbol: the globe of the app icon reduced to line work (outline, one
/// meridian, the equator), drawn in code so it follows the foreground style.
/// The app icon itself is unchanged.
struct JanusMarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addEllipse(in: rect)
        path.addEllipse(in: rect.insetBy(dx: rect.width * 0.28, dy: 0))
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

/// Symbol + JANUS wordmark; `height` is the symbol's visible height.
struct JanusLockup: View {
    var height: CGFloat

    var body: some View {
        let lineWidth = height * Theme.Size.markStrokeRatio
        HStack(spacing: Theme.Spacing.sm) {
            // Stroke inside the frame so the outline is never clipped.
            JanusMarkShape()
                .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .padding(lineWidth / 2)
                .frame(width: height, height: height)
            Text(verbatim: "JANUS")
                .font(Theme.Font.wordmark)
                .tracking(Theme.wordmarkTracking)
        }
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: "Janus"))
    }
}
