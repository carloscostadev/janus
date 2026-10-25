import AppKit
import SwiftUI

/// Single source of truth for the app's look: palette (light + dark), type scale,
/// spacing, radii and card styles. Views should not use literal colors or sizes.
///
/// Direction: monochrome and technical (after polar.sh, shared with Thoth). A
/// near-black grey scale in dark mode, white/grey-50 in light mode, hairline
/// borders, a large light display number, monospaced labels and values, and color
/// only where it carries meaning (a live port, a destructive action), always
/// desaturated, with one accent for the selected state (favorites).
enum Theme {

    // MARK: - Palette

    enum Palette {
        // Neutrals: dark mode follows the polar scale (950 / 800 / 700 / 600).
        static let background    = Color(light: 0xFFFFFF, dark: 0x090909)
        static let surface       = Color(light: 0xF9FAFB, dark: 0x181818)
        static let surfaceRaised = Color(light: 0xF3F4F6, dark: 0x292929)
        static let border        = Color(light: 0xE5E7EB, dark: 0x212121)

        // Text. Every tone keeps 4.5:1 (WCAG AA) on `background` and `surface`;
        // secondary also on `surfaceRaised` (see ThemeTests).
        static let textPrimary   = Color(light: 0x0A0A0A, dark: 0xFFFFFF)
        static let textSecondary = Color(light: 0x4B5563, dark: 0x9E9E9E)
        static let textTertiary  = Color(light: 0x6B7280, dark: 0x858585)

        /// The one subtle accent: selected state (a favorite port).
        static let accent   = Color(light: 0x2F6FEB, dark: 0x6B9BFF)
        /// A port that is listening.
        static let positive = Color(light: 0x2F7A50, dark: 0x7CC49A)
        /// Destructive actions (stop a process, stop all).
        static let negative = Color(light: 0xA84B37, dark: 0xD99484)
    }

    // MARK: - State accents

    /// Status dot of a port row: live, or fading while a kill/restart is pending.
    static func portStatusColor(isBusy: Bool) -> Color {
        isBusy ? Palette.textTertiary : Palette.positive
    }

    /// Status dot of the header chip.
    static func activityColor(hasPorts: Bool) -> Color {
        hasPorts ? Palette.positive : Palette.textTertiary
    }

    // MARK: - Typography

    enum Font {
        /// The big number of the popover (listening ports): light display.
        static let hero = SwiftUI.Font.system(size: 40, weight: .regular).monospacedDigit()
        static let body = SwiftUI.Font.system(size: 12, weight: .regular)
        static let bodyEmphasis = SwiftUI.Font.system(size: 12, weight: .medium)
        /// Numeric values in rows and metrics.
        static let number = SwiftUI.Font.system(size: 12, weight: .regular, design: .monospaced)
        /// The port of a row (":3000").
        static let port = SwiftUI.Font.system(size: 13, weight: .medium, design: .monospaced)
        static let caption = SwiftUI.Font.system(size: 11, weight: .regular)
        static let captionNumber = SwiftUI.Font.system(size: 10, weight: .regular, design: .monospaced)
        static let micro = SwiftUI.Font.system(size: 10, weight: .regular)
        static let microNumber = SwiftUI.Font.system(size: 9, weight: .regular, design: .monospaced)
        /// Small uppercase technical labels (used with `tracking`).
        static let sectionLabel = SwiftUI.Font.system(size: 10, weight: .medium, design: .monospaced)
        /// Group headings (project folder names keep their case).
        static let groupTitle = SwiftUI.Font.system(size: 11, weight: .medium, design: .monospaced)
        static let icon = SwiftUI.Font.system(size: 11, weight: .regular)
        /// Menu bar label: the port count next to the symbol.
        static let menuBarCount = SwiftUI.Font.system(.caption2, design: .rounded).weight(.bold)
        /// Glyph of the empty state.
        static let emptyIcon = SwiftUI.Font.system(size: 22, weight: .light)
    }

    /// Letter spacing for uppercase monospaced labels.
    static let labelTracking: CGFloat = 1.0

    // MARK: - Spacing, radii, sizes

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
    }

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
    }

    enum Size {
        static let popoverWidth: CGFloat = 380
        static let popoverDefaultHeight: CGFloat = 500
        /// The port list grows with its content up to this height, then scrolls.
        static let listMaxHeight: CGFloat = 420
        static let dot: CGFloat = 6
        static let hairline: CGFloat = 1
        /// Hit area of an icon-only button (the glyph itself is `Font.icon`).
        static let iconButton: CGFloat = 24
        /// Visible height of the symbol in the popover header's lockup.
        static let headerMark: CGFloat = 18
    }

    enum Opacity {
        /// A row while its kill/restart is pending.
        static let busy: Double = 0.5
    }

    enum Motion {
        static let hover = Animation.easeOut(duration: 0.12)
    }
}

// MARK: - Card styles

enum CardStyle {
    /// Standard content card: surface fill + hairline border.
    case plain
    /// Hero card: same shape, a faint top highlight and more breathing room.
    case hero
}

private struct ThemeCardModifier: ViewModifier {
    let style: CardStyle
    let padding: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: style == .hero ? Theme.Radius.lg : Theme.Radius.md,
                                     style: .continuous)
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                switch style {
                case .plain:
                    shape.fill(Theme.Palette.surface)
                case .hero:
                    shape.fill(Theme.Palette.surface)
                        .overlay(
                            shape.fill(LinearGradient(
                                colors: [Theme.Palette.textPrimary.opacity(0.04), .clear],
                                startPoint: .top,
                                endPoint: .center
                            ))
                        )
                }
            }
            .overlay(shape.strokeBorder(Theme.Palette.border, lineWidth: Theme.Size.hairline))
    }
}

/// Small uppercase monospaced label ("PORTS", "FAVORITES").
struct ThemeLabel: View {
    let text: String
    var color: Color = Theme.Palette.textTertiary

    init(_ text: String, color: Color = Theme.Palette.textTertiary) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text.uppercased())
            .font(Theme.Font.sectionLabel)
            .tracking(Theme.labelTracking)
            .foregroundStyle(color)
    }
}

/// Capsule chip with hairline border, optional leading status dot.
struct ThemeChip: View {
    let text: String
    var dot: Color? = nil
    var textColor: Color = Theme.Palette.textSecondary

    var body: some View {
        HStack(spacing: Theme.Spacing.xs + 1) {
            if let dot {
                Circle().fill(dot).frame(width: Theme.Size.dot, height: Theme.Size.dot)
            }
            Text(text.uppercased())
                .font(Theme.Font.captionNumber)
                .tracking(Theme.labelTracking / 2)
                .foregroundStyle(textColor)
        }
        .padding(.horizontal, Theme.Spacing.sm + 2)
        .padding(.vertical, Theme.Spacing.xs)
        .background(Capsule().fill(Theme.Palette.background))
        .overlay(Capsule().strokeBorder(Theme.Palette.border, lineWidth: Theme.Size.hairline))
    }
}

/// Hairline separator in the theme's border color.
struct ThemeDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.Palette.border)
            .frame(height: Theme.Size.hairline)
    }
}

/// Icon-only button with a comfortable hit area, a tooltip and an accessibility label.
struct ThemeIconButton: View {
    let systemImage: String
    let label: String
    var color: Color = Theme.Palette.textSecondary
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(Theme.Font.icon)
                .foregroundStyle(color)
                .frame(width: Theme.Size.iconButton, height: Theme.Size.iconButton)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                        .fill(isHovered ? Theme.Palette.surfaceRaised : .clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(label)
        .accessibilityLabel(label)
    }
}

extension View {
    func themeCard(_ style: CardStyle = .plain, padding: CGFloat = Theme.Spacing.lg) -> some View {
        modifier(ThemeCardModifier(style: style, padding: padding))
    }
}

// MARK: - Adaptive colors

extension Color {
    /// A color that resolves per appearance (light / dark), from 0xRRGGBB values.
    init(light: UInt32, dark: UInt32) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(rgb: isDark ? dark : light)
        })
    }
}

private extension NSColor {
    convenience init(rgb: UInt32) {
        self.init(
            srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
