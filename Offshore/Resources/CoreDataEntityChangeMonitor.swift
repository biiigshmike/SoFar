//
//  CoreDataEntityChangeMonitor.swift
//  SoFar
//
//  A small helper that watches Core Data change notifications and fires
//  a debounced callback only when specified entities are inserted/updated/deleted.
//  Use this to auto-refresh view models without flashing loaders.
//
//  Usage:
//    changeMonitor = CoreDataEntityChangeMonitor(
//        entityNames: ["Card"]
//    ) { [weak self] in
//        Task { await self?.loadAllCards(preserveLoadedFlag: true) }
//    }
//

import Foundation
import CoreData
import Combine

// MARK: - CoreDataEntityChangeMonitor
final class CoreDataEntityChangeMonitor {

    // MARK: Private
    private var cancellable: AnyCancellable?

    // MARK: Init
    /// - Parameters:
    ///   - entityNames: Entity names to listen for (e.g., ["Card"])
    ///   - debounceMilliseconds: Debounce to coalesce bursts of saves
    ///   - onRelevantChange: Called on the main thread when relevant entities change
    init(
        entityNames: [String],
        debounceMilliseconds: Int = 150,
        onRelevantChange: @escaping () -> Void
    ) {
        // IMPORTANT: Use the global Notification.Name constant.
        // (There is no `NSManagedObjectContext.objectsDidChangeNotification` static.)
        cancellable = NotificationCenter.default
            .publisher(for: .NSManagedObjectContextObjectsDidChange, object: nil)
            .compactMap { $0.userInfo }
            .map { userInfo -> Bool in
                // If any inserted/updated/deleted objects match our entities, mark relevant.
                let keys: [String] = [NSInsertedObjectsKey, NSUpdatedObjectsKey, NSDeletedObjectsKey]
                for key in keys {
                    if let set = userInfo[key] as? Set<NSManagedObject>,
                       set.contains(where: { obj in
                           guard let name = obj.entity.name else { return false }
                           return entityNames.contains(name)
                       }) {
                        return true
                    }
                }
                return false
            }
            .filter { $0 } // keep only relevant changes
            .debounce(for: .milliseconds(debounceMilliseconds), scheduler: RunLoop.main)
            .sink { _ in
                onRelevantChange()
            }
    }

    deinit {
        cancellable?.cancel()
    }
}
