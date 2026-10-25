import os
import ServiceManagement
import SwiftUI

struct PortListView: View {
    let scanner: PortScanner
    let favoritesManager: FavoritesManager
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    /// Two-step "Stop all": first click asks, second click kills.
    @State private var confirmStopAll: Bool
    /// Port whose row shows its hover actions without a pointer (snapshots).
    private let revealActionsForPort: Int?

    init(scanner: PortScanner, favoritesManager: FavoritesManager,
         confirmStopAll: Bool = false, revealActionsForPort: Int? = nil) {
        self.scanner = scanner
        self.favoritesManager = favoritesManager
        _confirmStopAll = State(initialValue: confirmStopAll)
        self.revealActionsForPort = revealActionsForPort
    }

    private var favoritePorts: [PortEntry] {
        scanner.ports.filter { favoritesManager.isFavorite(port: $0.port) }
    }

    private var nonFavoritePorts: [PortEntry] {
        scanner.ports.filter { !favoritesManager.isFavorite(port: $0.port) }
    }

    /// Groups non-favorite ports by their (already pre-computed) project root.
    private var groupedPorts: [(projectName: String, entries: [PortEntry])] {
        let grouped = Dictionary(grouping: nonFavoritePorts) { $0.projectRoot }
        return grouped
            .map { (projectName: ($0.key as NSString).lastPathComponent, entries: $0.value.sorted { $0.port < $1.port }) }
            .sorted { $0.projectName.localizedCaseInsensitiveCompare($1.projectName) == .orderedAscending }
    }

    private var processCount: Int {
        Set(scanner.ports.map(\.pid)).count
    }

    private var appVersion: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)

            ScrollView {
                portList
                    .padding(.horizontal, Theme.Spacing.lg - Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.sm)
            }
            .frame(maxHeight: Theme.Size.listMaxHeight)
            .padding(.top, Theme.Spacing.xs)

            if !scanner.ports.isEmpty {
                stopAllBar
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.sm)
            }

            ThemeDivider()

            footer
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.sm)
        }
        .frame(width: Theme.Size.popoverWidth)
        .background(Theme.Palette.background)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.sm) {
                JanusLockup(height: Theme.Size.headerMark)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Spacer()
                ThemeChip(
                    text: scanner.ports.isEmpty ? L("No Ports") : L("%d Active", scanner.ports.count),
                    dot: Theme.activityColor(hasPorts: !scanner.ports.isEmpty)
                )
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                HStack(alignment: .firstTextBaseline) {
                    ThemeLabel(L("Listening ports"))
                    Spacer()
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "arrow.clockwise")
                            .accessibilityHidden(true)
                        Text(L("Every 3s"))
                    }
                    .font(Theme.Font.captionNumber)
                    .foregroundStyle(Theme.Palette.textTertiary)
                }

                Text(verbatim: "\(scanner.ports.count)")
                    .font(Theme.Font.hero)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .contentTransition(.numericText())
                    .accessibilityLabel(L("%d Active", scanner.ports.count))

                HStack(spacing: 0) {
                    metric(label: L("FAVORITES"), value: favoritePorts.count)
                    metricDivider
                    metric(label: L("PROJECTS"), value: groupedPorts.count)
                    metricDivider
                    metric(label: L("Processes"), value: processCount)
                }
            }
            .themeCard(.hero, padding: Theme.Spacing.xl)
        }
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(Theme.Palette.border)
            .frame(width: Theme.Size.hairline, height: Theme.Spacing.xxl)
            .padding(.horizontal, Theme.Spacing.md)
    }

    private func metric(label: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            ThemeLabel(label)
            Text(verbatim: "\(value)")
                .font(Theme.Font.number)
                .foregroundStyle(Theme.Palette.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Port list

    @ViewBuilder
    private var portList: some View {
        if scanner.ports.isEmpty {
            emptyState
                .padding(.horizontal, Theme.Spacing.sm)
        } else {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                if !favoritePorts.isEmpty {
                    group(icon: "star.fill", iconColor: Theme.Palette.accent,
                          title: L("Favorites"), entries: favoritePorts, showPath: true)
                }

                ForEach(Array(groupedPorts.enumerated()), id: \.offset) { index, group in
                    if index > 0 || !favoritePorts.isEmpty {
                        ThemeDivider()
                            .padding(.horizontal, Theme.Spacing.sm)
                    }
                    self.group(icon: "folder", iconColor: Theme.Palette.textTertiary,
                               title: group.projectName, entries: group.entries,
                               showPath: group.entries.count == 1)
                }
            }
        }
    }

    private func group(icon: String, iconColor: Color, title: String, entries: [PortEntry],
                       showPath: Bool) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            HStack(spacing: Theme.Spacing.xs + Theme.Spacing.xxs) {
                Image(systemName: icon)
                    .font(Theme.Font.micro)
                    .foregroundStyle(iconColor)
                    .accessibilityHidden(true)
                Text(verbatim: title)
                    .font(Theme.Font.groupTitle)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Text(verbatim: "\(entries.count)")
                    .font(Theme.Font.microNumber)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.top, Theme.Spacing.xs)
            .padding(.bottom, Theme.Spacing.xxs)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            ForEach(entries) { entry in
                portRow(entry: entry, showPath: showPath)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "network")
                .font(Theme.Font.emptyIcon)
                .foregroundStyle(Theme.Palette.textTertiary)
                .accessibilityHidden(true)
            Text(L("No active ports"))
                .font(Theme.Font.bodyEmphasis)
                .foregroundStyle(Theme.Palette.textPrimary)
            Text(L("Dev servers show up here as soon as they listen on a port."))
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .themeCard(padding: Theme.Spacing.xl)
    }

    // MARK: - Stop all

    @ViewBuilder
    private var stopAllBar: some View {
        if confirmStopAll {
            let pids = Set(scanner.ports.map(\.pid))
            HStack(spacing: Theme.Spacing.sm) {
                Text(L("Stop %d processes?", pids.count))
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Spacer()
                Button {
                    confirmStopAll = false
                } label: {
                    ThemeChip(text: L("Cancel"))
                }
                .buttonStyle(.plain)
                Button {
                    confirmStopAll = false
                    for pid in pids {
                        ProcessManager.kill(pid: pid)
                    }
                    rescanAfter(seconds: 4)
                } label: {
                    ThemeChip(text: L("Stop"), dot: Theme.Palette.negative, textColor: Theme.Palette.negative)
                }
                .buttonStyle(.plain)
            }
            .themeCard(padding: Theme.Spacing.sm + Theme.Spacing.xxs)
        } else {
            HStack {
                Spacer()
                Button {
                    confirmStopAll = true
                } label: {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "xmark.circle")
                            .accessibilityHidden(true)
                        Text(L("Stop all"))
                    }
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.negative)
                    .padding(.vertical, Theme.Spacing.xs)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Footer (settings)

    private var footer: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Toggle(isOn: $launchAtLogin) {
                Text(L("Launch at login"))
            }
            .onChange(of: launchAtLogin) { _, newValue in
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    Logger(subsystem: "com.carloscosta.Janus", category: "LaunchAtLogin")
                        .error("Launch at login error: \(error.localizedDescription, privacy: .public)")
                    launchAtLogin = SMAppService.mainApp.status == .enabled
                }
            }
            .toggleStyle(.checkbox)
            .font(Theme.Font.caption)
            .foregroundStyle(Theme.Palette.textSecondary)
            Spacer()
            if let appVersion {
                Text(verbatim: "v\(appVersion)")
                    .font(Theme.Font.captionNumber)
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
            Button {
                relaunchApp()
            } label: {
                ThemeChip(text: L("Restart"))
            }
            .buttonStyle(.plain)
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                ThemeChip(text: L("Quit"))
            }
            .buttonStyle(.plain)
        }
    }

    private func portRow(entry: PortEntry, showPath: Bool = true) -> some View {
        PortRowView(
            entry: entry,
            isFavorite: favoritesManager.isFavorite(port: entry.port),
            showPath: showPath,
            onKill: {
                ProcessManager.kill(pid: entry.pid)
                rescanAfter(seconds: 4)
            },
            onOpenBrowser: {
                ProcessManager.openInBrowser(port: entry.port)
            },
            onRestart: {
                ProcessManager.restart(pid: entry.pid)
                rescanAfter(seconds: 4)
            },
            onToggleFavorite: {
                favoritesManager.toggle(port: entry.port)
            },
            onOpenInWarp: {
                ProcessManager.openTerminal(path: entry.projectPath)
            },
            revealActions: revealActionsForPort == entry.port
        )
    }

    /// Relaunch Janus. A helper waits for this instance to exit before
    /// reopening the bundle: launching the new copy while this one is still
    /// alive made the duplicate-instance guard quit the *new* copy, leaving
    /// no Janus running at all.
    private func relaunchApp() {
        let helper = Process()
        helper.executableURL = URL(fileURLWithPath: "/bin/sh")
        helper.arguments = [
            "-c", "while /bin/kill -0 \"$1\" 2>/dev/null; do sleep 0.2; done; /usr/bin/open \"$2\"",
            "sh", String(ProcessInfo.processInfo.processIdentifier), Bundle.main.bundlePath,
        ]
        do {
            try helper.run()
        } catch {
            Logger(subsystem: "com.carloscosta.Janus", category: "Relaunch")
                .error("relaunch helper failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        NSApplication.shared.terminate(nil)
    }

    /// Trigger a follow-up scan after `seconds` so the UI reflects the result
    /// of a kill/restart once the kernel has cleaned things up.
    private func rescanAfter(seconds: Int) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            scanner.scan()
        }
    }
}
