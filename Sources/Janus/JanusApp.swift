import AppKit
import Foundation
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
        JanusApp.migrateFromLocalPortsIfNeeded()

        _favoritesManager = State(initialValue: FavoritesManager())
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

    /// On the very first launch of Janus, copy favorites previously stored by LocalPorts
    /// so users renaming from the old app don't lose their pinned ports.
    private static func migrateFromLocalPortsIfNeeded() {
        let key = "favoritePorts"
        let defaults = UserDefaults.standard
        if defaults.object(forKey: key) != nil { return }

        let oldPlistPath = NSHomeDirectory() + "/Library/Preferences/com.carloscosta.LocalPorts.plist"
        guard FileManager.default.fileExists(atPath: oldPlistPath),
              let plist = NSDictionary(contentsOfFile: oldPlistPath) as? [String: Any],
              let oldFavorites = plist[key] as? [Int],
              !oldFavorites.isEmpty else { return }

        defaults.set(oldFavorites, forKey: key)
        print("Janus: migrated \(oldFavorites.count) favorite ports from LocalPorts")
    }
}
