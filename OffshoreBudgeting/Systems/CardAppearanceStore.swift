//
//  CardAppearanceStore.swift
//  SoFar
//
//  Persists per-card theme choices without changing the Core Data schema.
//  Uses UserDefaults under the hood.
//  Requires the iCloud Key-Value storage entitlement when syncing via iCloud.
//

import Foundation
import Combine

// MARK: - CardAppearanceStore
/// Persists per-card theme choices locally and, when available, via iCloud.
///
/// - Important: Enabling the iCloud sync path requires the target to include
///   the iCloud Key-Value storage entitlement.
@MainActor
final class CardAppearanceStore {

    // MARK: Singleton
    static let shared = CardAppearanceStore()

    // MARK: Storage Backbone
    private let userDefaults: UserDefaults
    private let ubiquitousStoreFactory: () -> UbiquitousKeyValueStoring
    private var cachedUbiquitousStore: UbiquitousKeyValueStoring?
    private let defaultCloudStatusProviderFactory: () -> CloudAvailabilityProviding
    private var pendingInjectedCloudStatusProvider: CloudAvailabilityProviding?
    private var cloudStatusProvider: CloudAvailabilityProviding?
    private let notificationCenter: NotificationCentering
    private let storageKey = "card.appearance.v1"

    /// In-memory cache for quick lookups.
    private var cache: [UUID: CardTheme] = [:]
    private var availabilityCancellable: AnyCancellable?
    private var hasRequestedCloudAvailabilityCheck = false
    private var ubiquitousObserver: NSObjectProtocol?

    private var isCardThemeSyncEnabled: Bool {
        let cardSync = userDefaults.object(forKey: AppSettingsKeys.syncCardThemes.rawValue) as? Bool ?? false
        let cloud = userDefaults.object(forKey: AppSettingsKeys.enableCloudSync.rawValue) as? Bool ?? false
        return cardSync && cloud
    }

    private var shouldUseICloud: Bool {
        guard isCardThemeSyncEnabled else { return false }
        let provider = resolveCloudStatusProvider()
        guard let available = provider.isCloudAccountAvailable else { return false }
        return available
    }

    private func resolveCloudStatusProvider() -> CloudAvailabilityProviding {
        if let provider = cloudStatusProvider {
            scheduleAvailabilityCheckIfNeeded(for: provider)
            return provider
        }

        let provider = pendingInjectedCloudStatusProvider ?? defaultCloudStatusProviderFactory()
        pendingInjectedCloudStatusProvider = nil
        cloudStatusProvider = provider

        availabilityCancellable?.cancel()
        availabilityCancellable = provider.availabilityPublisher
            .sink { [weak self] availability in
                self?.handleCloudAvailabilityChange(availability)
            }

        scheduleAvailabilityCheckIfNeeded(for: provider)
        return provider
    }

    private func scheduleAvailabilityCheckIfNeeded(for provider: CloudAvailabilityProviding) {
        guard !hasRequestedCloudAvailabilityCheck else { return }
        hasRequestedCloudAvailabilityCheck = true
        Task { @MainActor in
            _ = await provider.resolveAvailability(forceRefresh: false)
        }
    }

    // MARK: Init
    init(
        userDefaults: UserDefaults = .standard,
        ubiquitousStoreFactory: @escaping () -> UbiquitousKeyValueStoring = { NSUbiquitousKeyValueStore.default },
        cloudStatusProvider: CloudAvailabilityProviding? = nil,
        notificationCenter: NotificationCentering = NotificationCenterAdapter.shared
    ) {
        self.userDefaults = userDefaults
        self.ubiquitousStoreFactory = ubiquitousStoreFactory
        self.pendingInjectedCloudStatusProvider = cloudStatusProvider
        self.defaultCloudStatusProviderFactory = { CloudAccountStatusProvider.shared }
        self.notificationCenter = notificationCenter

        load()

        if shouldUseICloud {
            startObservingUbiquitousStoreIfNeeded()
        }
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
        if let store = ubiquitousStoreIfAvailable() {
            if store.synchronize() {
                data = store.data(forKey: storageKey) ?? userDefaults.data(forKey: storageKey)
            } else {
                handleUbiquitousStoreFailure()
                data = userDefaults.data(forKey: storageKey)
            }
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
            guard let store = ubiquitousStoreIfAvailable() else { return }

            guard store.synchronize() else {
                handleUbiquitousStoreFailure()
                return
            }

            store.set(data, forKey: storageKey)

            guard store.synchronize() else {
                handleUbiquitousStoreFailure()
                return
            }
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
        guard let store = ubiquitousStoreIfAvailable() else { return }
        ubiquitousObserver = notificationCenter.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store as AnyObject,
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

    private func instantiateUbiquitousStore() -> UbiquitousKeyValueStoring {
        if let store = cachedUbiquitousStore {
            return store
        }
        let store = ubiquitousStoreFactory()
        cachedUbiquitousStore = store
        return store
    }

    private func ubiquitousStoreIfAvailable() -> UbiquitousKeyValueStoring? {
        guard shouldUseICloud else { return nil }
        return instantiateUbiquitousStore()
    }

    private func handleUbiquitousStoreChange(_ note: Notification) {
        guard shouldUseICloud else { return }
        load()

        // Propagate the change so views can refresh themes immediately.
        notificationCenter.post(name: UserDefaults.didChangeNotification, object: nil)
    }

    private func handleUbiquitousStoreFailure() {
        stopObservingUbiquitousStore()
        CloudSyncPreferences.disableCardThemeSync(in: userDefaults)
        let provider = resolveCloudStatusProvider()
        provider.requestAccountStatusCheck(force: true)
        #if DEBUG
        print("⚠️ CardAppearanceStore: Falling back to UserDefaults after iCloud synchronize() failed.")
        #endif
    }
}
