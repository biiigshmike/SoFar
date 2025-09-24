//
//  CoreDataListObserver.swift
//  SoFar
//
//  A lightweight wrapper around NSFetchedResultsController that publishes
//  the current objects for a given fetch request. Works great for SwiftUI lists.
//
//  How to use:
//   let request: NSFetchRequest<Card> = Card.fetchRequest()
//   request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
//   observer = CoreDataListObserver(request: request,
//                                   context: CoreDataService.shared.viewContext) { [weak self] cards in
//       self?.apply(cards)
//   }
//   observer.start()
//

import Foundation
import CoreData

// MARK: - CoreDataListObserver
final class CoreDataListObserver<T: NSManagedObject>: NSObject, NSFetchedResultsControllerDelegate {

    // MARK: Stored
    private let controller: NSFetchedResultsController<T>
    private let onChange: ([T]) -> Void
    private var started = false

    // MARK: Init
    /// - Parameters:
    ///   - request: NSFetchRequest for the entity
    ///   - context: Managed object context (must be main-queue for UI delivery)
    ///   - sectionNameKeyPath: Optional sectioning
    ///   - onChange: Called on the main thread with the *current* fetched objects
    init(request: NSFetchRequest<T>,
         context: NSManagedObjectContext,
         sectionNameKeyPath: String? = nil,
         onChange: @escaping ([T]) -> Void) {
        self.controller = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: context,
            sectionNameKeyPath: sectionNameKeyPath,
            cacheName: nil
        )
        self.onChange = onChange
        super.init()
        self.controller.delegate = self
    }

    // MARK: start()
    /// Begins observing and immediately delivers the initial data set.
    func start() {
        guard !started else { return }
        started = true
        do {
            try controller.performFetch()
            onChange(controller.fetchedObjects ?? [])
        } catch {
            // If an error occurs, still deliver an empty list to keep UI stable.
            onChange([])
            AppLog.coreData.error("CoreDataListObserver start() error: \(String(describing: error))")
        }
    }

    // MARK: stop()
    /// Stops observing. You usually don't need to call this; deinit handles it.
    func stop() {
        controller.delegate = nil
    }

    // MARK: NSFetchedResultsControllerDelegate
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        // Deliver the latest snapshot after batched changes complete.
        if let objects = self.controller.fetchedObjects {
            onChange(objects)
        } else {
            onChange([])
        }
    }

    deinit {
        stop()
    }
}
