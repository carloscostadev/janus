import Foundation
import Observation

@Observable
final class FavoritesManager {
    static let defaultsKey = "favoritePorts"
    /// Preferences domain of the app before the rename to Janus.
    static let legacyDomain = "com.carloscosta.LocalPorts"

    @ObservationIgnored private let defaults: UserDefaults
    var favorites: Set<Int> {
        didSet { save() }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.array(forKey: Self.defaultsKey) as? [Int] ?? []
        favorites = Set(saved)
    }

    func toggle(port: Int) {
        if favorites.contains(port) {
            favorites.remove(port)
        } else {
            favorites.insert(port)
        }
    }

    func isFavorite(port: Int) -> Bool {
        favorites.contains(port)
    }

    private func save() {
        defaults.set(Array(favorites).sorted(), forKey: Self.defaultsKey)
    }

    /// One-shot migration: copy favorites stored by LocalPorts so users renaming
    /// from the old app don't lose their pinned ports. Does nothing once Janus
    /// has its own favorites key (even an empty one), so it never overwrites.
    /// Reads the legacy domain through `cfprefsd` (not the .plist file, which
    /// may not be flushed yet). Returns the number of migrated ports.
    @discardableResult
    static func migrateLegacyFavorites(
        into defaults: UserDefaults = .standard,
        from legacy: UserDefaults? = UserDefaults(suiteName: legacyDomain)
    ) -> Int {
        guard defaults.object(forKey: defaultsKey) == nil,
              let old = legacy?.array(forKey: defaultsKey) as? [Int],
              !old.isEmpty else { return 0 }
        defaults.set(old, forKey: defaultsKey)
        return old.count
    }
}
