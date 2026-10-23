import Foundation
import Testing
@testable import Janus

/// Fresh, isolated defaults domain per test; removed afterwards.
private func withTemporaryDefaults(_ body: (UserDefaults, UserDefaults) -> Void) {
    let current = "JanusTests.current.\(UUID().uuidString)"
    let legacy = "JanusTests.legacy.\(UUID().uuidString)"
    let currentDefaults = UserDefaults(suiteName: current)!
    let legacyDefaults = UserDefaults(suiteName: legacy)!
    defer {
        currentDefaults.removePersistentDomain(forName: current)
        legacyDefaults.removePersistentDomain(forName: legacy)
    }
    body(currentDefaults, legacyDefaults)
}

@Test func migratesLegacyFavoritesOnFirstLaunch() {
    withTemporaryDefaults { current, legacy in
        legacy.set([3000, 5173], forKey: FavoritesManager.defaultsKey)
        let migrated = FavoritesManager.migrateLegacyFavorites(into: current, from: legacy)
        #expect(migrated == 2)
        #expect(FavoritesManager(defaults: current).favorites == [3000, 5173])
    }
}

@Test func migrationNeverOverwritesExistingFavorites() {
    withTemporaryDefaults { current, legacy in
        legacy.set([3000], forKey: FavoritesManager.defaultsKey)
        // An empty list is still a deliberate user choice: don't re-import.
        current.set([Int](), forKey: FavoritesManager.defaultsKey)
        #expect(FavoritesManager.migrateLegacyFavorites(into: current, from: legacy) == 0)
        #expect(FavoritesManager(defaults: current).favorites.isEmpty)
    }
}

@Test func migrationWithoutLegacyDataIsNoOp() {
    withTemporaryDefaults { current, legacy in
        #expect(FavoritesManager.migrateLegacyFavorites(into: current, from: legacy) == 0)
        #expect(FavoritesManager.migrateLegacyFavorites(into: current, from: nil) == 0)
        #expect(current.object(forKey: FavoritesManager.defaultsKey) == nil)
    }
}

@Test func toggleFavoritePersists() {
    withTemporaryDefaults { current, _ in
        let manager = FavoritesManager(defaults: current)
        manager.toggle(port: 8080)
        #expect(manager.isFavorite(port: 8080))
        #expect(FavoritesManager(defaults: current).isFavorite(port: 8080))
        manager.toggle(port: 8080)
        #expect(!FavoritesManager(defaults: current).isFavorite(port: 8080))
    }
}
