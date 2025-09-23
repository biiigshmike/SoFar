//
//  OffshoreBudgetingTests.swift
//  OffshoreBudgetingTests
//
//  Created by Michael Brown on 8/11/25.
//

import Combine
import Foundation
import Testing
@testable import OffshoreBudgeting

struct OffshoreBudgetingTests {

    // MARK: - ThemeManager

    @Test
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
            ubiquitousStore: ubiquitousStore,
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

    // MARK: - CardAppearanceStore

    @Test
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
            ubiquitousStore: ubiquitousStore,
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
}

// MARK: - Test Doubles

private final class MockCloudAvailabilityProvider: CloudAvailabilityProviding {
    private let subject: CurrentValueSubject<CloudAccountStatusProvider.Availability, Never>

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

    func refreshAccountStatus(force: Bool) {
        // No-op for tests.
    }

    func send(_ availability: CloudAccountStatusProvider.Availability) {
        subject.send(availability)
    }
}

private final class MockUbiquitousKeyValueStore: UbiquitousKeyValueStoring {
    private var storage: [String: Any] = [:]
    private(set) var synchronizeCallCount = 0
    private(set) var setCallCount = 0

    @discardableResult
    func synchronize() -> Bool {
        synchronizeCallCount += 1
        return true
    }

    func string(forKey defaultName: String) -> String? {
        storage[defaultName] as? String
    }

    func data(forKey defaultName: String) -> Data? {
        storage[defaultName] as? Data
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
