//
//  OffshoreBudgetingTests.swift
//  OffshoreBudgetingTests
//
//  Created by Michael Brown on 8/11/25.
//

import CloudKit
import Combine
import Foundation
import Testing
@testable import OffshoreBudgeting

struct OffshoreBudgetingTests {

    // MARK: - CloudAccountStatusProvider

    @Test
    @MainActor
    func cloudAccountStatusProvider_resetsCacheWhenAccountChanges() async throws {
        let notificationCenter = MockNotificationCenter()
        let statusStream = AccountStatusStream()
        await statusStream.enqueue(.available)

        var provider: CloudAccountStatusProvider? = CloudAccountStatusProvider(
            notificationCenter: notificationCenter,
            accountStatusFetcher: {
                await statusStream.next()
            }
        )

        #expect(provider?.availability == .unknown)

#if os(macOS)
        if #available(macOS 10.16, *) {
            #expect(notificationCenter.addObserverCallCount == 1)
        } else {
            #expect(notificationCenter.addObserverCallCount == 0)
        }
#else
        #expect(notificationCenter.addObserverCallCount == 1)
#endif

        let isInitiallyAvailable = await provider?.resolveAvailability()
        #expect(isInitiallyAvailable == true)
        #expect(provider?.availability == .available)

        notificationCenter.post(name: .CKAccountChanged, object: nil)

        #expect(provider?.availability == .unknown)

        await statusStream.enqueue(.noAccount)

        let isFinallyAvailable = await provider?.resolveAvailability()
        #expect(isFinallyAvailable == false)
        #expect(provider?.availability == .unavailable)

        weak var weakProvider = provider
        provider = nil
        await Task.yield()

        #expect(weakProvider == nil)
#if os(macOS)
        if #available(macOS 10.16, *) {
            #expect(notificationCenter.removeObserverCallCount == 1)
        } else {
            #expect(notificationCenter.removeObserverCallCount == 0)
        }
#else
        #expect(notificationCenter.removeObserverCallCount == 1)
#endif
    }

    // MARK: - ThemeManager

    @Test
    @MainActor
    func themeManager_skipsCloudOperationsWhenAccountUnavailable() async throws {
        let suiteName = "ThemeManagerUnavailable"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(true, forKey: AppSettingsKeys.enableCloudSync.rawValue)
        defaults.set(true, forKey: AppSettingsKeys.syncAppTheme.rawValue)

        let ubiquitousStore = MockUbiquitousKeyValueStore()
        let cloudProvider = MockCloudAvailabilityProvider(initialAvailability: .unavailable)
        let notificationCenter = MockNotificationCenter()

        let manager = ThemeManager(
            userDefaults: defaults,
            ubiquitousStoreFactory: { ubiquitousStore },
            cloudStatusProvider: cloudProvider,
            notificationCenter: notificationCenter
        )

        manager.selectedTheme = .sunrise

        #expect(ubiquitousStore.synchronizeCallCount == 0)
        #expect(ubiquitousStore.setCallCount == 0)
        #expect(notificationCenter.addObserverCallCount == 0)
        #expect(defaults.bool(forKey: AppSettingsKeys.syncAppTheme.rawValue) == false)

        _ = manager // keep alive for test duration
    }

    @Test
    @MainActor
    func themeManager_disablesSyncWhenCloudSaveFails() async throws {
        let suiteName = "ThemeManagerSaveFailure"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(true, forKey: AppSettingsKeys.enableCloudSync.rawValue)
        defaults.set(true, forKey: AppSettingsKeys.syncAppTheme.rawValue)
        defaults.set(AppTheme.classic.rawValue, forKey: "selectedTheme")

        let ubiquitousStore = MockUbiquitousKeyValueStore()
        ubiquitousStore.synchronizeResults = [true, true, true, false]
        let cloudProvider = MockCloudAvailabilityProvider(initialAvailability: .available)
        let notificationCenter = MockNotificationCenter()

        let manager = ThemeManager(
            userDefaults: defaults,
            ubiquitousStoreFactory: { ubiquitousStore },
            cloudStatusProvider: cloudProvider,
            notificationCenter: notificationCenter
        )

        let initialSetCallCount = ubiquitousStore.setCallCount

        manager.selectedTheme = .sunrise

        #expect(ubiquitousStore.setCallCount == initialSetCallCount)
        #expect(defaults.bool(forKey: AppSettingsKeys.syncAppTheme.rawValue) == false)
        #expect(cloudProvider.requestAccountStatusCheckCalls.contains(true))

        _ = manager
    }

    @Test
    @MainActor
    func themeManager_fallsBackToLocalDefaultsWhenCloudLoadFails() async throws {
        let suiteName = "ThemeManagerLoadFailure"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(true, forKey: AppSettingsKeys.enableCloudSync.rawValue)
        defaults.set(true, forKey: AppSettingsKeys.syncAppTheme.rawValue)
        defaults.set(AppTheme.classic.rawValue, forKey: "selectedTheme")

        let ubiquitousStore = MockUbiquitousKeyValueStore()
        ubiquitousStore.synchronizeResults = [true, true, true, false]
        let cloudProvider = MockCloudAvailabilityProvider(initialAvailability: .available)
        let notificationCenter = MockNotificationCenter()

        let manager = ThemeManager(
            userDefaults: defaults,
            ubiquitousStoreFactory: { ubiquitousStore },
            cloudStatusProvider: cloudProvider,
            notificationCenter: notificationCenter
        )

        let initialStringCalls = ubiquitousStore.stringCallCount

        defaults.set(AppTheme.forest.rawValue, forKey: "selectedTheme")

        notificationCenter.post(
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: ubiquitousStore
        )

        await Task.yield()
        await Task.yield()
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(ubiquitousStore.stringCallCount == initialStringCalls)
        #expect(defaults.bool(forKey: AppSettingsKeys.syncAppTheme.rawValue) == false)
        #expect(cloudProvider.requestAccountStatusCheckCalls.contains(true))
        #expect(manager.selectedTheme == .forest)

        _ = manager
    }

    @Test
    @MainActor
    func themeManager_doesNotResolveUbiquitousStoreWhenSyncDisabled() async throws {
        let suiteName = "ThemeManagerLazyResolution"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(false, forKey: AppSettingsKeys.enableCloudSync.rawValue)
        defaults.set(false, forKey: AppSettingsKeys.syncAppTheme.rawValue)

        var factoryCallCount = 0
        let manager = ThemeManager(
            userDefaults: defaults,
            ubiquitousStoreFactory: {
                factoryCallCount += 1
                return MockUbiquitousKeyValueStore()
            },
            cloudStatusProvider: MockCloudAvailabilityProvider(initialAvailability: .available),
            notificationCenter: MockNotificationCenter()
        )

        manager.selectedTheme = .sunrise

        #expect(factoryCallCount == 0)

        _ = manager
    }

    // MARK: - CardAppearanceStore

    @Test
    @MainActor
    func cardAppearanceStore_skipsCloudOperationsWhenAccountUnavailable() throws {
        let suiteName = "CardAppearanceStoreUnavailable"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(true, forKey: AppSettingsKeys.enableCloudSync.rawValue)
        defaults.set(true, forKey: AppSettingsKeys.syncCardThemes.rawValue)

        let ubiquitousStore = MockUbiquitousKeyValueStore()
        let cloudProvider = MockCloudAvailabilityProvider(initialAvailability: .unavailable)
        let notificationCenter = MockNotificationCenter()

        let store = CardAppearanceStore(
            userDefaults: defaults,
            ubiquitousStoreFactory: { ubiquitousStore },
            cloudStatusProvider: cloudProvider,
            notificationCenter: notificationCenter
        )

        store.setTheme(.midnight, for: UUID())

        #expect(ubiquitousStore.synchronizeCallCount == 0)
        #expect(ubiquitousStore.setCallCount == 0)
        #expect(notificationCenter.addObserverCallCount == 0)
        #expect(defaults.bool(forKey: AppSettingsKeys.syncCardThemes.rawValue) == false)

        _ = store // keep alive for test duration
    }

    @Test
    @MainActor
    func cardAppearanceStore_fallsBackToLocalDefaultsWhenCloudLoadFails() throws {
        let suiteName = "CardAppearanceStoreLoadFailure"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(true, forKey: AppSettingsKeys.enableCloudSync.rawValue)
        defaults.set(true, forKey: AppSettingsKeys.syncCardThemes.rawValue)

        let cardID = UUID()
        let payload = [cardID.uuidString: CardTheme.midnight]
        let data = try JSONEncoder().encode(payload)
        defaults.set(data, forKey: "card.appearance.v1")

        let ubiquitousStore = MockUbiquitousKeyValueStore()
        ubiquitousStore.synchronizeResults = [false]
        let cloudProvider = MockCloudAvailabilityProvider(initialAvailability: .available)
        let notificationCenter = MockNotificationCenter()

        let store = CardAppearanceStore(
            userDefaults: defaults,
            ubiquitousStoreFactory: { ubiquitousStore },
            cloudStatusProvider: cloudProvider,
            notificationCenter: notificationCenter
        )

        #expect(ubiquitousStore.dataCallCount == 0)
        #expect(defaults.bool(forKey: AppSettingsKeys.syncCardThemes.rawValue) == false)
        #expect(cloudProvider.requestAccountStatusCheckCalls.contains(true))
        #expect(store.theme(for: cardID) == .midnight)

        _ = store
    }

    @Test
    @MainActor
    func cardAppearanceStore_doesNotResolveUbiquitousStoreWhenSyncDisabled() throws {
        let suiteName = "CardAppearanceStoreLazyResolution"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(false, forKey: AppSettingsKeys.enableCloudSync.rawValue)
        defaults.set(false, forKey: AppSettingsKeys.syncCardThemes.rawValue)

        var factoryCallCount = 0
        let store = CardAppearanceStore(
            userDefaults: defaults,
            ubiquitousStoreFactory: {
                factoryCallCount += 1
                return MockUbiquitousKeyValueStore()
            },
            cloudStatusProvider: MockCloudAvailabilityProvider(initialAvailability: .available),
            notificationCenter: MockNotificationCenter()
        )

        store.setTheme(.midnight, for: UUID())

        #expect(factoryCallCount == 0)

        _ = store
    }

    @Test
    @MainActor
    func cardAppearanceStore_disablesSyncWhenCloudSaveFails() throws {
        let suiteName = "CardAppearanceStoreSaveFailure"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(true, forKey: AppSettingsKeys.enableCloudSync.rawValue)
        defaults.set(true, forKey: AppSettingsKeys.syncCardThemes.rawValue)

        let ubiquitousStore = MockUbiquitousKeyValueStore()
        ubiquitousStore.synchronizeResults = [true, false]
        let cloudProvider = MockCloudAvailabilityProvider(initialAvailability: .available)
        let notificationCenter = MockNotificationCenter()

        let store = CardAppearanceStore(
            userDefaults: defaults,
            ubiquitousStoreFactory: { ubiquitousStore },
            cloudStatusProvider: cloudProvider,
            notificationCenter: notificationCenter
        )

        let cardID = UUID()

        store.setTheme(.midnight, for: cardID)

        #expect(ubiquitousStore.setCallCount == 0)
        #expect(defaults.bool(forKey: AppSettingsKeys.syncCardThemes.rawValue) == false)
        #expect(cloudProvider.requestAccountStatusCheckCalls.contains(true))
        #expect(store.theme(for: cardID) == .midnight)

        _ = store
    }

    @Test
    func coreDataService_enablesCloudKitWhenToggleOn() async throws {
        let defaults = UserDefaults.standard
        let previousEnable = defaults.object(forKey: AppSettingsKeys.enableCloudSync.rawValue)
        let previousCard = defaults.object(forKey: AppSettingsKeys.syncCardThemes.rawValue)
        let previousTheme = defaults.object(forKey: AppSettingsKeys.syncAppTheme.rawValue)
        let previousBudget = defaults.object(forKey: AppSettingsKeys.syncBudgetPeriod.rawValue)
        defer {
            if let previousEnable {
                defaults.set(previousEnable, forKey: AppSettingsKeys.enableCloudSync.rawValue)
            } else {
                defaults.removeObject(forKey: AppSettingsKeys.enableCloudSync.rawValue)
            }
            if let previousCard {
                defaults.set(previousCard, forKey: AppSettingsKeys.syncCardThemes.rawValue)
            } else {
                defaults.removeObject(forKey: AppSettingsKeys.syncCardThemes.rawValue)
            }
            if let previousTheme {
                defaults.set(previousTheme, forKey: AppSettingsKeys.syncAppTheme.rawValue)
            } else {
                defaults.removeObject(forKey: AppSettingsKeys.syncAppTheme.rawValue)
            }
            if let previousBudget {
                defaults.set(previousBudget, forKey: AppSettingsKeys.syncBudgetPeriod.rawValue)
            } else {
                defaults.removeObject(forKey: AppSettingsKeys.syncBudgetPeriod.rawValue)
            }
        }

        defaults.set(true, forKey: AppSettingsKeys.enableCloudSync.rawValue)
        defaults.set(true, forKey: AppSettingsKeys.syncCardThemes.rawValue)
        defaults.set(true, forKey: AppSettingsKeys.syncAppTheme.rawValue)
        defaults.set(true, forKey: AppSettingsKeys.syncBudgetPeriod.rawValue)

        let provider = MockCloudAvailabilityProvider(initialAvailability: .available)
        let shouldEnable = await CoreDataService.shared.shouldEnableCloudKitSync(using: provider)

        #expect(shouldEnable)
        #expect(provider.resolveAvailabilityCallCount == 1)
    }

    @Test
    func coreDataService_disablesCloudKitWhenToggleOff() async throws {
        let defaults = UserDefaults.standard
        let previousEnable = defaults.object(forKey: AppSettingsKeys.enableCloudSync.rawValue)
        let previousCard = defaults.object(forKey: AppSettingsKeys.syncCardThemes.rawValue)
        let previousTheme = defaults.object(forKey: AppSettingsKeys.syncAppTheme.rawValue)
        let previousBudget = defaults.object(forKey: AppSettingsKeys.syncBudgetPeriod.rawValue)
        defer {
            if let previousEnable {
                defaults.set(previousEnable, forKey: AppSettingsKeys.enableCloudSync.rawValue)
            } else {
                defaults.removeObject(forKey: AppSettingsKeys.enableCloudSync.rawValue)
            }
            if let previousCard {
                defaults.set(previousCard, forKey: AppSettingsKeys.syncCardThemes.rawValue)
            } else {
                defaults.removeObject(forKey: AppSettingsKeys.syncCardThemes.rawValue)
            }
            if let previousTheme {
                defaults.set(previousTheme, forKey: AppSettingsKeys.syncAppTheme.rawValue)
            } else {
                defaults.removeObject(forKey: AppSettingsKeys.syncAppTheme.rawValue)
            }
            if let previousBudget {
                defaults.set(previousBudget, forKey: AppSettingsKeys.syncBudgetPeriod.rawValue)
            } else {
                defaults.removeObject(forKey: AppSettingsKeys.syncBudgetPeriod.rawValue)
            }
        }

        defaults.set(false, forKey: AppSettingsKeys.enableCloudSync.rawValue)
        defaults.set(true, forKey: AppSettingsKeys.syncCardThemes.rawValue)
        defaults.set(true, forKey: AppSettingsKeys.syncAppTheme.rawValue)
        defaults.set(true, forKey: AppSettingsKeys.syncBudgetPeriod.rawValue)

        let provider = MockCloudAvailabilityProvider(initialAvailability: .available)
        let shouldEnable = await CoreDataService.shared.shouldEnableCloudKitSync(using: provider)

        #expect(!shouldEnable)
        #expect(provider.resolveAvailabilityCallCount == 0)
        #expect(defaults.bool(forKey: AppSettingsKeys.syncCardThemes.rawValue) == false)
        #expect(defaults.bool(forKey: AppSettingsKeys.syncAppTheme.rawValue) == false)
        #expect(defaults.bool(forKey: AppSettingsKeys.syncBudgetPeriod.rawValue) == false)
    }

    // MARK: - Glass Background Policy

    @Test
    func glassBackgroundPolicy_usesGlassOnlyWhenThemeAndOSAllow() {
        let modern = PlatformCapabilities(supportsOS26Translucency: true, supportsAdaptiveKeypad: true)
        let legacy = PlatformCapabilities(supportsOS26Translucency: false, supportsAdaptiveKeypad: false)

        // OS 26 devices (modern) render Liquid Glass for glass-enabled themes.
        #expect(UBGlassBackgroundPolicy.shouldUseGlassSurfaces(theme: .sunrise, capabilities: modern))
        #expect(!UBGlassBackgroundPolicy.shouldUseGlassSurfaces(theme: .sunrise, capabilities: legacy))
        #expect(!UBGlassBackgroundPolicy.shouldUseGlassSurfaces(theme: .system, capabilities: modern))
    }

    @Test
    func glassBackgroundPolicy_chromeFallsBackOnLegacyOS() {
        let modern = PlatformCapabilities(supportsOS26Translucency: true, supportsAdaptiveKeypad: true)
        let legacy = PlatformCapabilities(supportsOS26Translucency: false, supportsAdaptiveKeypad: false)

        // Chrome (tab bars/toolbars) stays opaque on OS 15.4 and earlier builds.
        #expect(UBGlassBackgroundPolicy.shouldUseSystemChrome(capabilities: modern))
        #expect(!UBGlassBackgroundPolicy.shouldUseSystemChrome(capabilities: legacy))
    }
}

// MARK: - Test Doubles

@MainActor
private final class MockCloudAvailabilityProvider: CloudAvailabilityProviding {
    private let subject: CurrentValueSubject<CloudAccountStatusProvider.Availability, Never>
    private(set) var requestAccountStatusCheckCalls: [Bool] = []
    private(set) var resolveAvailabilityCallCount = 0
    private(set) var invalidateCacheCallCount = 0

    init(initialAvailability: CloudAccountStatusProvider.Availability) {
        subject = .init(initialAvailability)
    }

    var isCloudAccountAvailable: Bool? {
        switch subject.value {
        case .available:
            return true
        case .unavailable:
            return false
        case .unknown:
            return nil
        }
    }

    var availabilityPublisher: AnyPublisher<CloudAccountStatusProvider.Availability, Never> {
        subject.eraseToAnyPublisher()
    }

    func requestAccountStatusCheck(force: Bool) {
        requestAccountStatusCheckCalls.append(force)
    }

    func resolveAvailability(forceRefresh: Bool) async -> Bool {
        resolveAvailabilityCallCount += 1
        switch subject.value {
        case .available:
            return true
        case .unavailable, .unknown:
            return false
        }
    }

    func invalidateCache() {
        invalidateCacheCallCount += 1
    }

    func send(_ availability: CloudAccountStatusProvider.Availability) {
        subject.send(availability)
    }
}

private final class MockUbiquitousKeyValueStore: UbiquitousKeyValueStoring {
    private var storage: [String: Any] = [:]
    private(set) var synchronizeCallCount = 0
    private(set) var setCallCount = 0
    private(set) var stringCallCount = 0
    private(set) var dataCallCount = 0
    var synchronizeResults: [Bool] = []
    var defaultSynchronizeResult: Bool = true

    @discardableResult
    func synchronize() -> Bool {
        synchronizeCallCount += 1
        if !synchronizeResults.isEmpty {
            return synchronizeResults.removeFirst()
        }
        return defaultSynchronizeResult
    }

    func string(forKey defaultName: String) -> String? {
        stringCallCount += 1
        return storage[defaultName] as? String
    }

    func data(forKey defaultName: String) -> Data? {
        dataCallCount += 1
        return storage[defaultName] as? Data
    }

    func set(_ value: Any?, forKey defaultName: String) {
        setCallCount += 1
        storage[defaultName] = value
    }
}

private final class MockNotificationCenter: NotificationCentering {
    private(set) var addObserverCallCount = 0
    private(set) var removeObserverCallCount = 0
    private(set) var postedNames: [NSNotification.Name] = []
    private var observers: [ObserverToken] = []

    @discardableResult
    func addObserver(
        forName name: NSNotification.Name?,
        object obj: Any?,
        queue: OperationQueue?,
        using block: @escaping @Sendable (Notification) -> Void
    ) -> NSObjectProtocol {
        addObserverCallCount += 1
        let token = ObserverToken(name: name, object: obj as AnyObject?, handler: block)
        observers.append(token)
        return token
    }

    func removeObserver(_ observer: Any) {
        removeObserverCallCount += 1
        guard let token = observer as? ObserverToken else { return }
        observers.removeAll { $0 === token }
    }

    func post(name: NSNotification.Name, object obj: Any?) {
        postedNames.append(name)
        observers
            .filter { $0.matches(name: name, object: obj as AnyObject?) }
            .forEach { $0.handler(Notification(name: name, object: obj)) }
    }
}

private final class ObserverToken: NSObject {
    let name: NSNotification.Name?
    weak var object: AnyObject?
    let handler: @Sendable (Notification) -> Void

    init(name: NSNotification.Name?, object: AnyObject?, handler: @escaping @Sendable (Notification) -> Void) {
        self.name = name
        self.object = object
        self.handler = handler
    }

    func matches(name: NSNotification.Name, object: AnyObject?) -> Bool {
        let nameMatches = self.name == nil || self.name == name
        let objectMatches = self.object == nil || self.object === object
        return nameMatches && objectMatches
    }
}

private actor AccountStatusStream {
    private var bufferedStatuses: [CKAccountStatus] = []
    private var waitingContinuations: [CheckedContinuation<CKAccountStatus, Never>] = []

    func enqueue(_ status: CKAccountStatus) {
        if !waitingContinuations.isEmpty {
            let continuation = waitingContinuations.removeFirst()
            continuation.resume(returning: status)
        } else {
            bufferedStatuses.append(status)
        }
    }

    func next() async -> CKAccountStatus {
        if !bufferedStatuses.isEmpty {
            return bufferedStatuses.removeFirst()
        }

        return await withCheckedContinuation { continuation in
            waitingContinuations.append(continuation)
        }
    }
}
