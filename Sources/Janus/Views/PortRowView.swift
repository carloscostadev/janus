import SwiftUI

struct PortRowView: View {
    let entry: PortEntry
    let isFavorite: Bool
    var showPath: Bool = true
    let onKill: () -> Void
    let onOpenBrowser: () -> Void
    let onRestart: () -> Void
    let onToggleFavorite: () -> Void
    let onOpenInWarp: () -> Void
    /// Shows the hover actions without a pointer (snapshots).
    var revealActions: Bool = false
    /// A stop or restart of this port is running (set by the list, which
    /// knows when the action really ends).
    var isBusy: Bool = false
    @State private var isHovered = false

    private var isKilling: Bool { isBusy }

    private var showsActions: Bool { isHovered || revealActions || isKilling }

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.sm) {
            Circle()
                .fill(Theme.portStatusColor(isBusy: isKilling))
                .frame(width: Theme.Size.dot, height: Theme.Size.dot)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                    Text(verbatim: ":\(entry.port)")
                        .font(Theme.Font.port)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text(verbatim: entry.processName)
                        .font(Theme.Font.captionNumber)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .lineLimit(1)
                    Text(verbatim: "PID \(entry.pid)")
                        .font(Theme.Font.captionNumber)
                        .foregroundStyle(Theme.Palette.textTertiary)
                        .lineLimit(1)
                }

                if showPath && entry.displayPath.contains("/") {
                    Text(verbatim: entry.displayPath)
                        .font(Theme.Font.captionNumber)
                        .foregroundStyle(Theme.Palette.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilitySummary)
            .accessibilityAction(named: favoriteLabel, onToggleFavorite)
            .accessibilityAction(named: L("Open in terminal"), onOpenInWarp)
            .accessibilityAction(named: L("Open in browser"), onOpenBrowser)
            .accessibilityAction(named: L("Restart process"), restart)
            .accessibilityAction(named: L("Stop process"), kill)

            Spacer(minLength: Theme.Spacing.xs)

            actions
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs + Theme.Spacing.xxs)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .fill(isHovered ? Theme.Palette.surface : .clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(Theme.Motion.hover) { isHovered = hovering }
        }
        .opacity(isKilling ? Theme.Opacity.busy : 1)
    }

    /// Discreet actions: shown on hover, except a favorite's star, which stays as
    /// the row's selected state.
    private var actions: some View {
        HStack(spacing: 0) {
            Group {
                ThemeIconButton(systemImage: "terminal", label: L("Open in terminal"), action: onOpenInWarp)
                ThemeIconButton(systemImage: "globe", label: L("Open in browser"), action: onOpenBrowser)
                ThemeIconButton(systemImage: "arrow.clockwise", label: L("Restart process"), action: restart)
                if isKilling {
                    ProgressView()
                        .controlSize(.mini)
                        .frame(width: Theme.Size.iconButton, height: Theme.Size.iconButton)
                } else {
                    ThemeIconButton(systemImage: "xmark.circle", label: L("Stop process"),
                                    color: Theme.Palette.negative, action: kill)
                }
            }
            .disabled(isKilling)
            .opacity(showsActions ? 1 : 0)

            ThemeIconButton(
                systemImage: isFavorite ? "star.fill" : "star",
                label: favoriteLabel,
                color: isFavorite ? Theme.Palette.accent : Theme.Palette.textSecondary,
                action: onToggleFavorite
            )
            .opacity(showsActions || isFavorite ? 1 : 0)
        }
    }

    private var favoriteLabel: String {
        isFavorite ? L("Remove from favorites") : L("Add to favorites")
    }

    private var accessibilitySummary: String {
        var parts = [L("Port %d", entry.port), entry.processName, "PID \(entry.pid)"]
        if showPath && entry.displayPath.contains("/") { parts.append(entry.displayPath) }
        if isFavorite { parts.append(L("Favorites")) }
        return parts.joined(separator: ", ")
    }

    private func restart() {
        guard !isBusy else { return }
        onRestart()
    }

    private func kill() {
        guard !isBusy else { return }
        onKill()
    }
}
