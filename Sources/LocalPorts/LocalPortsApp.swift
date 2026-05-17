import AppKit
import SwiftUI

@main
struct LocalPortsApp: App {
    @State private var scanner = PortScanner()
    @State private var favoritesManager = FavoritesManager()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)

        let bundleID = Bundle.main.bundleIdentifier ?? "com.carloscosta.LocalPorts"
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        if running.count > 1 {
            NSApplication.shared.terminate(nil)
        }

        scanner.startPolling()
    }

    var body: some Scene {
        MenuBarExtra {
            PortListView(scanner: scanner, favoritesManager: favoritesManager)
        } label: {
            HStack(spacing: 2) {
                Image(systemName: "network")
                    .font(.body)
                if !scanner.ports.isEmpty {
                    Text("\(String(scanner.ports.count))")
                        .font(.system(.caption2, design: .rounded))
                        .fontWeight(.bold)
                }
            }
        }
        .menuBarExtraStyle(.window)
        .defaultSize(width: 380, height: 500)
    }
}
