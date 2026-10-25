import AppKit
import SwiftUI
import Testing
@testable import Janus

/// WCAG 2.x contrast of the palette, resolved per appearance.
@MainActor
struct ThemeTests {
    typealias P = Theme.Palette

    nonisolated static let appearances: [NSAppearance.Name] = [.aqua, .darkAqua]

    /// Relative luminance of `color` resolved under `appearance` (sRGB).
    static func luminance(_ color: Color, _ appearance: NSAppearance.Name) -> Double {
        var result = 0.0
        NSAppearance(named: appearance)!.performAsCurrentDrawingAppearance {
            let rgb = NSColor(color).usingColorSpace(.sRGB)!
            func channel(_ c: CGFloat) -> Double {
                let c = Double(c)
                return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
            }
            result = 0.2126 * channel(rgb.redComponent)
                + 0.7152 * channel(rgb.greenComponent)
                + 0.0722 * channel(rgb.blueComponent)
        }
        return result
    }

    static func contrast(_ a: Color, _ b: Color, _ appearance: NSAppearance.Name) -> Double {
        let la = luminance(a, appearance), lb = luminance(b, appearance)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    @Test func lightAndDarkResolveDifferently() {
        #expect(Self.luminance(P.background, .aqua) > 0.9)
        #expect(Self.luminance(P.background, .darkAqua) < 0.01)
    }

    /// Text tones on the backgrounds they are drawn on: AA for normal text (4.5:1).
    @Test(arguments: appearances)
    func textMeetsAA(_ appearance: NSAppearance.Name) {
        let text: [(String, Color)] = [
            ("textPrimary", P.textPrimary), ("textSecondary", P.textSecondary),
            ("textTertiary", P.textTertiary), ("negative", P.negative),
        ]
        for (bgName, bg) in [("background", P.background), ("surface", P.surface)] {
            for (name, fg) in text {
                let ratio = Self.contrast(fg, bg, appearance)
                #expect(ratio >= 4.5, "\(name) on \(bgName) (\(appearance.rawValue)): \(ratio)")
            }
        }
        // Hovered rows and buttons sit on surfaceRaised: icons and secondary text.
        for (name, fg) in [("textPrimary", P.textPrimary), ("textSecondary", P.textSecondary)] {
            let ratio = Self.contrast(fg, P.surfaceRaised, appearance)
            #expect(ratio >= 4.5, "\(name) on surfaceRaised (\(appearance.rawValue)): \(ratio)")
        }
    }

    /// Status dots and icon accents: AA for non-text graphics (3:1).
    @Test(arguments: appearances)
    func accentsMeetNonTextAA(_ appearance: NSAppearance.Name) {
        for (name, fg) in [("accent", P.accent), ("positive", P.positive), ("negative", P.negative)] {
            for bg in [P.background, P.surface, P.surfaceRaised] {
                let ratio = Self.contrast(fg, bg, appearance)
                #expect(ratio >= 3, "\(name) (\(appearance.rawValue)): \(ratio)")
            }
        }
    }
}
