import Foundation
import Observation

@Observable
final class FavoritesManager {
    private let key = "favoritePorts"
    var favorites: Set<Int> {
        didSet { save() }
    }

    init() {
        let saved = UserDefaults.standard.array(forKey: key) as? [Int] ?? []
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
        UserDefaults.standard.set(Array(favorites), forKey: key)
    }
}
