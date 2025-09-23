//
//  CloudAccountStatusProvider.swift
//  SoFar
//
//  Created by OpenAI Assistant on 2024-05-17.
//

import CloudKit
import Combine
import Foundation

/// Centralized helper that reports whether the user currently has access to the
/// configured iCloud container. The provider caches the most recent
/// `CKAccountStatus` value so multiple features (Core Data setup, onboarding,
/// settings) can make a fast decision without repeatedly hitting CloudKit.
@MainActor
final class CloudAccountStatusProvider: ObservableObject {

    // MARK: Shared Instance

    /// Identifier that matches the entitlements and Core Data configuration.
    static let containerIdentifier = "iCloud.com.mbrown.offshore"

    static let shared = CloudAccountStatusProvider()

    // MARK: Availability State

    enum Availability: Equatable {
        case unknown
        case available
        case unavailable
    }

    @Published private(set) var availability: Availability = .unknown

    /// Returns `true` when `availability == .available` and `false` when the
    /// check has finished and determined that iCloud is not usable. Returns
    /// `nil` while the provider is still determining availability.
    var isCloudAccountAvailable: Bool? {
        switch availability {
        case .available:
            return true
        case .unavailable:
            return false
        case .unknown:
            return nil
        }
    }

    // MARK: Private Properties

    typealias AccountStatusFetcher = @Sendable () async throws -> CKAccountStatus

    private let notificationCenter: NotificationCentering
    private let accountStatusFetcher: AccountStatusFetcher
    private var accountChangeObserver: NSObjectProtocol?
    private var cachedStatus: CKAccountStatus?
    private var fetchTask: Task<CKAccountStatus, Error>?

    // MARK: Init

    init(
        container: CKContainer? = nil,
        notificationCenter: NotificationCentering = NotificationCenterAdapter.shared,
        accountStatusFetcher: AccountStatusFetcher? = nil
    ) {
        self.notificationCenter = notificationCenter

        if let accountStatusFetcher {
            self.accountStatusFetcher = accountStatusFetcher
        } else {
            let resolvedContainer = container ?? CKContainer(identifier: Self.containerIdentifier)
            self.accountStatusFetcher = {
                try await resolvedContainer.accountStatus()
            }
        }

        registerForAccountChanges()
    }

    deinit {
        fetchTask?.cancel()

        if let accountChangeObserver {
            notificationCenter.removeObserver(accountChangeObserver)
        }
    }

    // MARK: Public API

    /// Starts a background task (if one is not already running) to refresh the
    /// CloudKit account status. Useful for callers that do not need the result
    /// immediately but want to make sure the cache stays fresh.
    func requestAccountStatusCheck(force: Bool = false) {
        Task { [weak self] in
            guard let self else { return }
            _ = await self.resolveAvailability(forceRefresh: force)
        }
    }

    /// Returns whether iCloud is currently available. When the status has not
    /// been fetched yet this method queries CloudKit and caches the result.
    /// - Parameter forceRefresh: When `true`, bypasses any cached value and
    ///   re-queries CloudKit.
    /// - Returns: `true` when the user has an available iCloud account for the
    ///   configured container.
    func resolveAvailability(forceRefresh: Bool = false) async -> Bool {
        if forceRefresh {
            cachedStatus = nil
            fetchTask?.cancel()
            fetchTask = nil
            availability = .unknown
        }

        if let cachedStatus, !forceRefresh {
            let available = cachedStatus == .available
            availability = available ? .available : .unavailable
            return available
        }

        if let fetchTask, !forceRefresh {
            return await resolve(task: fetchTask)
        }

        let fetcher = accountStatusFetcher
        let task = Task { () throws -> CKAccountStatus in
            try await fetcher()
        }
        fetchTask = task

        return await resolve(task: task)
    }

    /// Removes any cached status so the next call to `resolveAvailability`
    /// fetches from CloudKit again.
    func invalidateCache() {
        cachedStatus = nil
        fetchTask?.cancel()
        fetchTask = nil
        availability = .unknown
    }

    // MARK: Private Helpers

    private func registerForAccountChanges() {
#if canImport(CloudKit)
#if os(macOS)
        if #available(macOS 10.16, *) {
            accountChangeObserver = notificationCenter.addObserver(
                forName: .CKAccountChanged,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleAccountChangeNotification()
                }
            }
        }
#else
        accountChangeObserver = notificationCenter.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleAccountChangeNotification()
            }
        }
#endif
#endif
    }

    private func handleAccountChangeNotification() {
        invalidateCache()
        requestAccountStatusCheck(force: true)
    }

    private func resolve(task: Task<CKAccountStatus, Error>) async -> Bool {
        defer { fetchTask = nil }

        do {
            let status = try await task.value
            cachedStatus = status
            let available = status == .available
            availability = available ? .available : .unavailable
            return available
        } catch {
            cachedStatus = .noAccount
            availability = .unavailable
            return false
        }
    }
}

// MARK: - CloudAvailabilityProviding

@MainActor
protocol CloudAvailabilityProviding: AnyObject {
    var isCloudAccountAvailable: Bool? { get }
    var availabilityPublisher: AnyPublisher<CloudAccountStatusProvider.Availability, Never> { get }
    func requestAccountStatusCheck(force: Bool)
    func resolveAvailability(forceRefresh: Bool) async -> Bool
    func invalidateCache()
}

@MainActor
extension CloudAccountStatusProvider: CloudAvailabilityProviding {
    var availabilityPublisher: AnyPublisher<Availability, Never> {
        $availability.eraseToAnyPublisher()
    }
}
