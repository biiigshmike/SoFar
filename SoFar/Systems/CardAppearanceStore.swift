//
//  CardAppearanceStore.swift
//  SoFar
//
//  Persists per-card theme choices without changing the Core Data schema.
//  Uses UserDefaults under the hood.
//

import Foundation

// MARK: - CardAppearanceStore
final class CardAppearanceStore {

    // MARK: Singleton
    static let shared = CardAppearanceStore()

    // MARK: Storage Backbone
    private let userDefaults: UserDefaults
    private let storageKey = "card.appearance.v1"

    /// In-memory cache for quick lookups.
    private var cache: [UUID: CardTheme] = [:]

    // MARK: Init
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        load()
    }

    // MARK: load()
    /// Hydrates the in-memory cache from UserDefaults.
    private func load() {
        guard let data = userDefaults.data(forKey: storageKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([String: CardTheme].self, from: data)
            self.cache = Dictionary(uniqueKeysWithValues: decoded.compactMap { (key, theme) in
                if let id = UUID(uuidString: key) { return (id, theme) }
                return nil
            })
        } catch {
            // If decoding fails, start fresh (avoid crashing the app).
            self.cache = [:]
        }
    }

    // MARK: save()
    /// Writes the current cache to UserDefaults.
    private func save() {
        let dict = Dictionary(uniqueKeysWithValues: cache.map { (id, theme) in
            (id.uuidString, theme)
        })
        if let data = try? JSONEncoder().encode(dict) {
            userDefaults.set(data, forKey: storageKey)
        }
    }

    // MARK: theme(for:)
    /// Retrieves stored theme for a card, defaulting to a pleasant option.
    func theme(for id: UUID) -> CardTheme {
        cache[id] ?? .rose
    }

    // MARK: setTheme(_:for:)
    /// Saves/overwrites the theme for a card.
    func setTheme(_ theme: CardTheme, for id: UUID) {
        cache[id] = theme
        save()
    }

    // MARK: removeTheme(for:)
    /// Removes a stored theme when a card is deleted.
    func removeTheme(for id: UUID) {
        cache.removeValue(forKey: id)
        save()
    }
}
