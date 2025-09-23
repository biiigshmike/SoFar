//
//  CardAppearanceStore.swift
//  SoFar
//
//  Persists per-card theme choices without changing the Core Data schema.
//  Uses UserDefaults under the hood.
//

import Foundation
import Combine

// MARK: - CardAppearanceStore
@MainActor
final class CardAppearanceStore {

    // MARK: Singleton
    static let shared = CardAppearanceStore()

    // MARK: Storage Backbone
    private let userDefaults: UserDefaults
    private let ubiquitousStore: UbiquitousKeyValueStoring
    private let cloudStatusProvider: CloudAvailabilityProviding
    private let notificationCenter: NotificationCentering
    private let storageKey = "card.appearance.v1"

    /// In-memory cache for quick lookups.
    private var cache: [UUID: CardTheme] = [:]
    private var availabilityCancellable: AnyCancellable?
    private var ubiquitousObserver: NSObjectProtocol?

    private var isCardThemeSyncEnabled: Bool {
        let cardSync = userDefaults.object(forKey: AppSettingsKeys.syncCardThemes.rawValue) as? Bool ?? false
        let cloud = userDefaults.object(forKey: AppSettingsKeys.enableCloudSync.rawValue) as? Bool ?? false
        return cardSync && cloud
    }

    private var shouldUseICloud: Bool {
        guard let available = cloudStatusProvider.isCloudAccountAvailable else { return false }
        return available && isCardThemeSyncEnabled
    }

    // MARK: Init
    init(
        userDefaults: UserDefaults = .standard,
        ubiquitousStore: UbiquitousKeyValueStoring = NSUbiquitousKeyValueStore.default,
        cloudStatusProvider: CloudAvailabilityProviding? = nil,
        notificationCenter: NotificationCentering = NotificationCenterAdapter.shared
    ) {
        self.userDefaults = userDefaults
        self.ubiquitousStore = ubiquitousStore
        let resolvedCloudStatusProvider = cloudStatusProvider ?? CloudAccountStatusProvider.shared
        self.cloudStatusProvider = resolvedCloudStatusProvider
        self.notificationCenter = notificationCenter

        load()

        if shouldUseICloud {
            startObservingUbiquitousStoreIfNeeded()
        }

        availabilityCancellable = resolvedCloudStatusProvider.availabilityPublisher
            .sink { [weak self] availability in
                self?.handleCloudAvailabilityChange(availability)
            }

        resolvedCloudStatusProvider.refreshAccountStatus(force: false)
    }

    @MainActor
    deinit {
        availabilityCancellable?.cancel()
        stopObservingUbiquitousStore()
    }

    // MARK: load()
    /// Hydrates the in-memory cache from UserDefaults and optionally iCloud.
    private func load() {
        let data: Data?
        if shouldUseICloud {
            _ = ubiquitousStore.synchronize()
            data = ubiquitousStore.data(forKey: storageKey) ?? userDefaults.data(forKey: storageKey)
        } else {
            data = userDefaults.data(forKey: storageKey)
        }

        guard let data else { return }
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
    /// Writes the current cache to UserDefaults and optionally iCloud.
    private func save() {
        let dict = Dictionary(uniqueKeysWithValues: cache.map { (id, theme) in
            (id.uuidString, theme)
        })
        if let data = try? JSONEncoder().encode(dict) {
            userDefaults.set(data, forKey: storageKey)
            guard shouldUseICloud else { return }
            ubiquitousStore.set(data, forKey: storageKey)
            _ = ubiquitousStore.synchronize()
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

    private func handleCloudAvailabilityChange(_ availability: CloudAccountStatusProvider.Availability) {
        switch availability {
        case .available:
            guard isCardThemeSyncEnabled else { return }
            startObservingUbiquitousStoreIfNeeded()
            load()
        case .unavailable:
            stopObservingUbiquitousStore()
            CloudSyncPreferences.disableCardThemeSync(in: userDefaults)
        case .unknown:
            break
        }
    }

    private func startObservingUbiquitousStoreIfNeeded() {
        guard ubiquitousObserver == nil else { return }
        ubiquitousObserver = notificationCenter.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: ubiquitousStore as AnyObject,
            queue: nil
        ) { [weak self] note in
            Task { @MainActor [weak self, note] in
                self?.handleUbiquitousStoreChange(note)
            }
        }
    }

    private func stopObservingUbiquitousStore() {
        if let observer = ubiquitousObserver {
            notificationCenter.removeObserver(observer)
            ubiquitousObserver = nil
        }
    }

    private func handleUbiquitousStoreChange(_ note: Notification) {
        guard shouldUseICloud else { return }
        load()

        // Propagate the change so views can refresh themes immediately.
        notificationCenter.post(name: UserDefaults.didChangeNotification, object: nil)
    }
}
