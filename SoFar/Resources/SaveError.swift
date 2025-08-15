//
//  SaveError.swift
//  SoFar
//
//  Shared, user-presentable error used across views and view models.
//

import Foundation
import CoreData

// MARK: - SaveError
/// A single, shared error type that can wrap Core Data errors or plain string messages.
/// Conforms to `Identifiable` for `.alert(item:)`.
public enum SaveError: Error, LocalizedError, Identifiable {
    // MARK: Cases
    case coreData(NSError)
    case message(String)

    // MARK: Identifiable
    /// Stable enough for alerts; two identical messages will share the same id.
    public var id: String { message }

    // MARK: Presentation
    /// A readable, user-facing string for this error.
    public var message: String {
        switch self {
        case .message(let m):
            return m
        case .coreData(let e):
            return Self.describe(e)
        }
    }

    public var errorDescription: String? { message }

    // MARK: Bridging
    /// Keeps compatibility with existing VM helpers that expect an `Error`.
    public func asPublicError() -> Error { self }

    // MARK: Pretty Printer for Core Data
    /// Produces a friendly message for common Core Data `NSError`s.
    public static func describe(_ error: NSError) -> String {
        // Multi-error (code 1560): show count and the first detailed failure.
        if error.code == NSValidationMultipleErrorsError,
           let nested = error.userInfo[NSDetailedErrorsKey] as? [NSError],
           !nested.isEmpty {
            return "Validation failed (\(nested.count) issues). First: " + describe(nested[0])
        }

        // Extract common Core Data context.
        let object = error.userInfo[NSValidationObjectErrorKey] as AnyObject?
        let key = error.userInfo[NSValidationKeyErrorKey] as? String
        let entityName = (object as? NSManagedObject)?.entity.name

        // Friendlier messages for frequent validation codes.
        switch error.code {
        case NSValidationMissingMandatoryPropertyError: // 1570
            return "“\(entityName ?? "Object")” is missing a required value for “\(key ?? "?")”."
        case NSValidationNumberTooSmallError: // 1556
            return "“\(entityName ?? "Number")” for “\(key ?? "?")” is too small."
        case NSValidationNumberTooLargeError: // 1557
            return "“\(entityName ?? "Number")” for “\(key ?? "?")” is too large."
        case NSValidationRelationshipLacksMinimumCountError: // 1581
            return "“\(entityName ?? "Object")” must have at least one “\(key ?? "related object")”."
        case NSPersistentStoreSaveError: // 134110
            return "Couldn’t write to the persistent store. (\(error.domain) \(error.code))"
        default:
            if let reason = error.localizedFailureReason, !reason.isEmpty {
                return reason
            }
            return error.localizedDescription
        }
    }
}
