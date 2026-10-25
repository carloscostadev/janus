import AppKit
import SwiftUI
import Testing
@testable import Janus

/// Renders PNG snapshots of the popover with sample data, in light and dark.
/// Opt-in: runs only when JANUS_SNAPSHOT_DIR points to an output folder, e.g.
/// `JANUS_SNAPSHOT_DIR=/tmp/janus-snapshots swift test --filter SnapshotTests`.
@MainActor
@Suite(.enabled(if: ProcessInfo.processInfo.environment["JANUS_SNAPSHOT_DIR"] != nil))
struct SnapshotTests {
    static let samplePorts: [PortEntry] = [
        PortEntry(pid: 41210, port: 3000, projectPath: "~/dev/acme-web", processName: "node", projectRoot: "/dev/acme-web"),
        PortEntry(pid: 41210, port: 3001, projectPath: "~/dev/acme-web/apps/admin", processName: "node", projectRoot: "/dev/acme-web"),
        PortEntry(pid: 41388, port: 5173, projectPath: "~/dev/landing", processName: "node", projectRoot: "/dev/landing"),
        PortEntry(pid: 40977, port: 5432, projectPath: "postgres", processName: "postgres", projectRoot: "postgres"),
        PortEntry(pid: 41502, port: 8000, projectPath: "~/dev/api", processName: "Python", projectRoot: "/dev/api"),
        PortEntry(pid: 41600, port: 8080, projectPath: "~/dev/api/worker", processName: "java", projectRoot: "/dev/worker"),
    ]

    static func makeFavorites(_ ports: [Int]) -> FavoritesManager {
        let defaults = UserDefaults(suiteName: "JanusSnapshotTests-\(UUID().uuidString)")!
        let manager = FavoritesManager(defaults: defaults)
        ports.forEach(manager.toggle)
        return manager
    }

    static func scanner(with ports: [PortEntry]) -> PortScanner {
        let scanner = PortScanner()
        scanner.ports = ports
        return scanner
    }

    /// `ImageRenderer` draws neither ScrollView content nor AppKit-backed controls
    /// (the checkbox), so the view is hosted in an off-screen window and cached.
    func render(_ view: some View, name: String) throws {
        let dir = URL(fileURLWithPath: ProcessInfo.processInfo.environment["JANUS_SNAPSHOT_DIR"]!)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for (suffix, appearance) in [("light", NSAppearance.Name.aqua), ("dark", NSAppearance.Name.darkAqua)] {
            let host = NSHostingView(rootView: view)
            let window = NSWindow(contentRect: NSRect(x: -10_000, y: -10_000, width: 380, height: 600),
                                  styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.appearance = NSAppearance(named: appearance)
            window.contentView = host
            host.setFrameSize(host.fittingSize)
            window.setContentSize(host.fittingSize)
            host.layoutSubtreeIfNeeded()
            host.display()
            let rep = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: rep)
            let data = try #require(rep.representation(using: .png, properties: [:]))
            try data.write(to: dir.appendingPathComponent("janus-\(name)-\(suffix).png"))
            window.close()
        }
    }

    @Test func withPorts() throws {
        let view = PortListView(scanner: Self.scanner(with: Self.samplePorts),
                                favoritesManager: Self.makeFavorites([5432]),
                                revealActionsForPort: 3000)
        try render(view, name: "ports")
    }

    @Test func empty() throws {
        let view = PortListView(scanner: Self.scanner(with: []), favoritesManager: Self.makeFavorites([]))
        try render(view, name: "empty")
    }

    @Test func confirmStopAll() throws {
        let view = PortListView(scanner: Self.scanner(with: Self.samplePorts),
                                favoritesManager: Self.makeFavorites([5432]),
                                confirmStopAll: true)
        try render(view, name: "stop-all")
    }
}
