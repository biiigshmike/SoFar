//
//  CloudAccountStatusProvider.swift
//  SoFar
//
//  Simplified stub for local-only builds. Always reports iCloud as unavailable
//  and performs no CloudKit calls.
//

import Combine
import Foundation

/// Centralized helper that reports whether the user currently has access to the
/// configured iCloud container. The provider caches the most recent
/// `CKAccountStatus` value so multiple features (Core Data setup, onboarding,
/// settings) can make a fast decision without repeatedly hitting CloudKit.
@MainActor
final class CloudAccountStatusProvider: ObservableObject {

    // MARK: Shared Instance

    /// Kept for API compatibility only.
    static let containerIdentifier = ""

    static let shared = CloudAccountStatusProvider()

    // MARK: Availability State

    enum Availability: Equatable {
        case unknown
        case available
        case unavailable
    }

    @Published private(set) var availability: Availability = .unavailable

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

    // MARK: Init
    init() {}

    deinit {
        // no-op
    }

    // MARK: Public API

    /// Starts a background task (if one is not already running) to refresh the
    /// CloudKit account status. Useful for callers that do not need the result
    /// immediately but want to make sure the cache stays fresh.
    func requestAccountStatusCheck(force: Bool = false) { /* no-op */ }

    /// Returns whether iCloud is currently available. When the status has not
    /// been fetched yet this method queries CloudKit and caches the result.
    /// - Parameter forceRefresh: When `true`, bypasses any cached value and
    ///   re-queries CloudKit.
    /// - Returns: `true` when the user has an available iCloud account for the
    ///   configured container.
    func resolveAvailability(forceRefresh: Bool = false) async -> Bool { false }

    /// Removes any cached status so the next call to `resolveAvailability`
    /// fetches from CloudKit again.
    func invalidateCache() { /* no-op */ }

    // MARK: Private Helpers

    // No observers or CloudKit interactions in stub.
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
