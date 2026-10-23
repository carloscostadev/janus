import os
import ServiceManagement
import SwiftUI

struct PortListView: View {
    let scanner: PortScanner
    let favoritesManager: FavoritesManager
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    /// Two-step "Stop all": first click asks, second click kills.
    @State private var confirmStopAll = false

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

    var body: some View {
        VStack(spacing: 0) {
            // HEADER
            VStack(spacing: 0) {
                HStack {
                    Text(verbatim: "Janus")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    HStack(spacing: 4) {
                        Circle()
                            .fill(scanner.ports.isEmpty ? .gray : .green)
                            .frame(width: 8, height: 8)
                        Text(scanner.ports.isEmpty ? L("No Ports") : L("%d Active", scanner.ports.count))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            // STAT CARDS
            HStack(spacing: 8) {
                StatCard(icon: "🔌", title: L("PORTS"), value: "\(scanner.ports.count)", titleColor: .blue)
                StatCard(icon: "⭐", title: L("FAVORITES"), value: "\(favoritePorts.count)", titleColor: .yellow)
                StatCard(icon: "📁", title: L("PROJECTS"), value: "\(groupedPorts.count)", titleColor: .green)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            Divider()
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            // PORT LIST
            ScrollView {
                VStack(spacing: 6) {
                    if scanner.ports.isEmpty {
                        Text(L("No active ports"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(20)
                    } else {
                        // Favorites section
                        if !favoritePorts.isEmpty {
                            sectionHeader(icon: "star.fill", title: L("Favorites"), color: .yellow)
                            ForEach(favoritePorts) { entry in
                                portRow(entry: entry)
                            }
                        }

                        // Grouped sections
                        ForEach(Array(groupedPorts.enumerated()), id: \.offset) { _, group in
                            sectionHeader(icon: "folder", title: group.projectName, color: .secondary)
                            ForEach(group.entries) { entry in
                                portRow(entry: entry, showPath: group.entries.count == 1)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(maxHeight: 300)

            // STOP ALL button (only when ports exist)
            if !scanner.ports.isEmpty {
                Divider()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)

                if confirmStopAll {
                    let pids = Set(scanner.ports.map(\.pid))
                    HStack(spacing: 8) {
                        Text(L("Stop %d processes?", pids.count))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(L("Cancel")) {
                            confirmStopAll = false
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        Button(L("Stop")) {
                            confirmStopAll = false
                            for pid in pids {
                                ProcessManager.kill(pid: pid)
                            }
                            rescanAfter(seconds: 4)
                        }
                        .buttonStyle(.plain)
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                    }
                    .padding(.horizontal, 16)
                } else {
                    Button {
                        confirmStopAll = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                            Text(L("Stop all"))
                                .font(.caption)
                        }
                        .foregroundStyle(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                }
            }

            // REFRESH INFO
            Divider()
                .padding(.horizontal, 16)
                .padding(.vertical, 4)

            HStack {
                Image(systemName: "arrow.clockwise")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(L("Every 3s"))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text(verbatim: "v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)

            Divider()
                .padding(.horizontal, 16)

            // FOOTER
            HStack {
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
                .font(.caption)
                .foregroundStyle(.secondary)
                Spacer()
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label {
                        Text(L("Quit"))
                    } icon: {
                        Image(systemName: "xmark.circle")
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.caption)
                Button {
                    relaunchApp()
                } label: {
                    Label {
                        Text(L("Restart"))
                    } icon: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.caption)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(width: 380)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func sectionHeader(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
        .padding(.bottom, 2)
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
            }
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

// STAT CARD
struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let titleColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(icon)
                    .font(.caption2)
                Text(title)
                    .font(.caption2.bold())
                    .foregroundStyle(titleColor)
            }
            Text(value)
                .font(.system(.body, design: .monospaced).bold())
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
