import ServiceManagement
import SwiftUI

struct PortListView: View {
    let scanner: PortScanner
    let favoritesManager: FavoritesManager
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    private var favoritePorts: [PortEntry] {
        scanner.ports.filter { favoritesManager.isFavorite(port: $0.port) }
    }

    private var nonFavoritePorts: [PortEntry] {
        scanner.ports.filter { !favoritesManager.isFavorite(port: $0.port) }
    }

    /// Groups non-favorite ports by their project root.
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
                    Text("Janus")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    HStack(spacing: 4) {
                        Circle()
                            .fill(scanner.ports.isEmpty ? .gray : .green)
                            .frame(width: 8, height: 8)
                        Text(scanner.ports.isEmpty ? "No Ports" : "\(scanner.ports.count) Active")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            // STAT CARDS
            HStack(spacing: 8) {
                StatCard(icon: "🔌", title: "PORTS", value: "\(scanner.ports.count)", titleColor: .blue)
                StatCard(icon: "⭐", title: "FAVORITES", value: "\(favoritePorts.count)", titleColor: .yellow)
                StatCard(icon: "📁", title: "PROJECTS", value: "\(groupedPorts.count)", titleColor: .green)
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
                        Text("Nenhuma porta ativa")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(20)
                    } else {
                        // Favorites section
                        if !favoritePorts.isEmpty {
                            sectionHeader(icon: "star.fill", title: "Favoritos", color: .yellow)
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

                Button {
                    for entry in scanner.ports {
                        ProcessManager.kill(pid: entry.pid)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        scanner.scan()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                        Text("Parar todas")
                            .font(.caption)
                    }
                    .foregroundStyle(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
            }

            // REFRESH INFO
            Divider()
                .padding(.horizontal, 16)
                .padding(.vertical, 4)

            HStack {
                Image(systemName: "arrow.clockwise")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text("A cada 3s")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)

            Divider()
                .padding(.horizontal, 16)

            // FOOTER
            HStack {
                Toggle("Abrir ao iniciar", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            print("Launch at login error: \(error)")
                        }
                    }
                    .toggleStyle(.checkbox)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Sair", systemImage: "xmark.circle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.caption)
                Button {
                    let url = Bundle.main.bundleURL
                    let config = NSWorkspace.OpenConfiguration()
                    config.createsNewApplicationInstance = true
                    NSWorkspace.shared.openApplication(at: url, configuration: config)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        NSApplication.shared.terminate(nil)
                    }
                } label: {
                    Label("Reiniciar", systemImage: "arrow.clockwise")
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    scanner.scan()
                }
            },
            onOpenBrowser: {
                ProcessManager.openInBrowser(port: entry.port)
            },
            onRestart: {
                ProcessManager.restart(pid: entry.pid)
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    scanner.scan()
                }
            },
            onToggleFavorite: {
                favoritesManager.toggle(port: entry.port)
            },
            onOpenInWarp: {
                ProcessManager.openTerminal(path: entry.projectPath)
            }
        )
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
