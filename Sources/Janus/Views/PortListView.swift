import os
import ServiceManagement
import SwiftUI

struct PortListView: View {
    let scanner: PortScanner
    let favoritesManager: FavoritesManager
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    /// Two-step "Stop all": first click asks, second click kills.
    @State private var confirmStopAll: Bool
    /// Measured height of the port list, so the ScrollView can size to it.
    @State private var listHeight: CGFloat = 0
    /// Port whose row shows its hover actions without a pointer (snapshots).
    private let revealActionsForPort: Int?
    /// Status of the last action (stop, restart, stop all, open terminal).
    @State private var feedback: ActionFeedback?
    /// Bumped on every new feedback, so an older auto-clear never hides a newer one.
    @State private var feedbackToken = 0
    /// Ports with a stop or restart in progress (their rows show a spinner).
    @State private var busyPorts: Set<Int>

    init(scanner: PortScanner, favoritesManager: FavoritesManager,
         confirmStopAll: Bool = false, revealActionsForPort: Int? = nil,
         feedback: ActionFeedback? = nil, busyPorts: Set<Int> = []) {
        self.scanner = scanner
        self.favoritesManager = favoritesManager
        _confirmStopAll = State(initialValue: confirmStopAll)
        self.revealActionsForPort = revealActionsForPort
        _feedback = State(initialValue: feedback)
        _busyPorts = State(initialValue: busyPorts)
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

            if scanner.lastScanFailed {
                scanFailedNotice
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.sm)
            }

            // A MenuBarExtra window sizes itself to the ideal size of its content,
            // and a ScrollView's ideal height is near zero. Measure the list and
            // give the ScrollView an explicit height (capped) so every row shows.
            ScrollView {
                portList
                    .padding(.horizontal, Theme.Spacing.lg - Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(key: ListHeightKey.self, value: proxy.size.height)
                        }
                    )
            }
            .onPreferenceChange(ListHeightKey.self) { listHeight = $0 }
            .frame(height: min(listHeight, Theme.Size.listMaxHeight))
            .padding(.top, Theme.Spacing.xs)

            if let feedback {
                feedbackLine(feedback)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.sm)
            }

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

    // MARK: - Scan failure and action feedback

    private var scanFailedNotice: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(Theme.Palette.negative)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(L("Couldn't read ports · retrying"))
                    .font(Theme.Font.bodyEmphasis)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(L("The list may be out of date."))
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .themeCard(padding: Theme.Spacing.sm + Theme.Spacing.xxs)
        .accessibilityElement(children: .combine)
    }

    private func feedbackLine(_ feedback: ActionFeedback) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            switch feedback.tone {
            case .working:
                ProgressView()
                    .controlSize(.mini)
            case .success:
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(Theme.Palette.positive)
                    .accessibilityHidden(true)
            case .failure:
                Image(systemName: "exclamationmark.circle")
                    .foregroundStyle(Theme.Palette.negative)
                    .accessibilityHidden(true)
            }
            Text(verbatim: feedback.text)
                .font(Theme.Font.caption)
                .foregroundStyle(feedback.tone == .failure ? Theme.Palette.negative : Theme.Palette.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .themeCard(padding: Theme.Spacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }

    /// Show `newFeedback`; results clear themselves after a few seconds,
    /// "working" lines stay until the result replaces them.
    private func show(_ newFeedback: ActionFeedback) {
        feedbackToken += 1
        let token = feedbackToken
        withAnimation(Theme.Motion.hover) { feedback = newFeedback }
        guard newFeedback.tone != .working else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(newFeedback.tone == .failure ? 8 : 5))
            if feedbackToken == token {
                withAnimation(Theme.Motion.hover) { feedback = nil }
            }
        }
    }

    private func stop(_ entry: PortEntry) {
        guard !busyPorts.contains(entry.port) else { return }
        busyPorts.insert(entry.port)
        show(.working(L(":%d · Stopping…", entry.port)))
        Task { @MainActor in
            let result = await ProcessManager.stop(pid: entry.pid, port: entry.port, expected: entry.identity)
            busyPorts.remove(entry.port)
            show(.forStop(result, port: entry.port))
            scanner.scan()
        }
    }

    private func restart(_ entry: PortEntry) {
        guard !busyPorts.contains(entry.port) else { return }
        busyPorts.insert(entry.port)
        show(.working(L(":%d · Restarting…", entry.port)))
        Task { @MainActor in
            let result = await ProcessManager.restart(pid: entry.pid, port: entry.port, expected: entry.identity)
            busyPorts.remove(entry.port)
            show(.forRestart(result, port: entry.port))
            scanner.scan()
        }
    }

    /// Stop every listed process (one entry per PID), in parallel.
    private func stopAll() {
        let targets = Dictionary(grouping: scanner.ports, by: \.pid).compactMap { $0.value.first }
        guard !targets.isEmpty else { return }
        let ports = Set(scanner.ports.map(\.port))
        busyPorts.formUnion(ports)
        show(.working(L("Stopping %d processes…", targets.count)))
        Task { @MainActor in
            var ended = 0
            await withTaskGroup(of: Bool.self) { group in
                for entry in targets {
                    group.addTask {
                        let result = await ProcessManager.stop(pid: entry.pid, port: entry.port, expected: entry.identity)
                        return ActionFeedback.processEnded(result)
                    }
                }
                for await didEnd in group where didEnd { ended += 1 }
            }
            busyPorts.subtract(ports)
            show(.forStopAll(ended: ended, total: targets.count))
            scanner.scan()
        }
    }

    private func openTerminal(_ entry: PortEntry) {
        let path = entry.projectPath
        Task { @MainActor in
            let opened = await Task.detached { ProcessManager.openTerminal(path: path) }.value
            if !opened { show(.failure(L("Couldn't open the terminal"))) }
        }
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
                    stopAll()
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
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                launchAtLoginToggle
                Toggle(isOn: Binding(get: { scanner.showSystemProcesses },
                                     set: { scanner.showSystemProcesses = $0 })) {
                    Text(L("Show system processes"))
                }
                .toggleStyle(.checkbox)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .help(L("Also list system services and desktop apps hidden by default."))
            }
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

    private var launchAtLoginToggle: some View {
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
    }

    private func portRow(entry: PortEntry, showPath: Bool = true) -> some View {
        PortRowView(
            entry: entry,
            isFavorite: favoritesManager.isFavorite(port: entry.port),
            showPath: showPath,
            onKill: { stop(entry) },
            onOpenBrowser: {
                ProcessManager.openInBrowser(port: entry.port)
            },
            onRestart: { restart(entry) },
            onToggleFavorite: {
                favoritesManager.toggle(port: entry.port)
            },
            onOpenInWarp: { openTerminal(entry) },
            revealActions: revealActionsForPort == entry.port,
            isBusy: busyPorts.contains(entry.port)
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
}

/// Height of the port list content, read by `PortListView` to size its ScrollView.
private struct ListHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
