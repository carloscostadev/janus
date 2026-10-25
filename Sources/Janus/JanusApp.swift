import AppKit
import Foundation
import os
import SwiftUI

@main
struct JanusApp: App {
    @State private var scanner = PortScanner()
    @State private var favoritesManager: FavoritesManager

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)

        let bundleID = Bundle.main.bundleIdentifier ?? "com.carloscosta.Janus"
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        if running.count > 1 {
            NSApplication.shared.terminate(nil)
        }

        // One-shot migration: pull favorites from the old LocalPorts bundle on first launch.
        let migrated = FavoritesManager.migrateLegacyFavorites()
        if migrated > 0 {
            Logger(subsystem: "com.carloscosta.Janus", category: "Migration")
                .info("migrated \(migrated, privacy: .public) favorite ports from LocalPorts")
        }

        _favoritesManager = State(initialValue: FavoritesManager())
        scanner.startPolling()
    }

    var body: some Scene {
        MenuBarExtra {
            PortListView(scanner: scanner, favoritesManager: favoritesManager)
        } label: {
            HStack(spacing: Theme.Spacing.xxs) {
                Image(systemName: "network")
                    .font(Theme.Font.menuBarIcon)
                if !scanner.ports.isEmpty {
                    Text("\(String(scanner.ports.count))")
                        .font(Theme.Font.menuBarCount)
                }
            }
        }
        .menuBarExtraStyle(.window)
        .defaultSize(width: Theme.Size.popoverWidth, height: Theme.Size.popoverDefaultHeight)
    }
}
