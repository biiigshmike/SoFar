//
//  CoreDataRepository.swift
//  SoFar
//
//  A generic repository to centralize common Core Data operations.
//  This keeps typed services tiny and consistent across entities.
//

import Foundation
import CoreData

// MARK: - CoreDataStackProviding
/// Protocol that exposes an NSPersistentContainer. CoreDataService already conforms in practice.
public protocol CoreDataStackProviding: AnyObject {
    var container: NSPersistentContainer { get }
}

// MARK: - CoreDataService + CoreDataStackProviding
extension CoreDataService: CoreDataStackProviding {}

// MARK: - CoreDataRepository
/// Generic repository for NSManagedObject subclasses.
/// Use in typed services (e.g., BudgetService) to avoid repeating boilerplate.
final class CoreDataRepository<Entity: NSManagedObject> {
    
    // MARK: Properties
    /// The Core Data container provider (defaults to CoreDataService.shared).
    private let stack: CoreDataStackProviding
    
    /// Convenience accessor for the main context (UI / main thread).
    private var viewContext: NSManagedObjectContext { stack.container.viewContext }

    /// Exposes the underlying view context for advanced operations.
    var context: NSManagedObjectContext { viewContext }
    
    // MARK: Init
    /// Initialize with a custom stack (useful for tests), defaults to CoreDataService.shared.
    init(stack: CoreDataStackProviding = CoreDataService.shared) {
        self.stack = stack
    }
    
    // MARK: fetchAll(...)
    /// Fetch all entities with optional predicate/sort/limit.
    /// - Parameters:
    ///   - predicate: NSPredicate to filter results.
    ///   - sortDescriptors: Sort descriptors for ordering.
    ///   - fetchLimit: Optional fetch limit.
    ///   - faults: Whether to return faults (default false for UI).
    /// - Returns: Array of `Entity`.
    func fetchAll(predicate: NSPredicate? = nil,
                  sortDescriptors: [NSSortDescriptor] = [],
                  fetchLimit: Int? = nil,
                  faults: Bool = false) throws -> [Entity] {
        let request = NSFetchRequest<Entity>(entityName: String(describing: Entity.self))
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors
        request.returnsObjectsAsFaults = faults
        if let fetchLimit { request.fetchLimit = fetchLimit }
        return try viewContext.fetch(request)
    }
    
    // MARK: fetchFirst(...)
    /// Fetch the first entity matching the predicate and sort descriptors.
    func fetchFirst(predicate: NSPredicate? = nil,
                    sortDescriptors: [NSSortDescriptor] = []) throws -> Entity? {
        try fetchAll(predicate: predicate, sortDescriptors: sortDescriptors, fetchLimit: 1).first
    }
    
    // MARK: count(...)
    /// Count entities matching the given predicate.
    func count(predicate: NSPredicate? = nil) throws -> Int {
        let request = NSFetchRequest<NSNumber>(entityName: String(describing: Entity.self))
        request.resultType = .countResultType
        request.predicate = predicate
        let results = try viewContext.fetch(request)
        return results.first?.intValue ?? 0
    }
    
    // MARK: create(configure:)
    /// Create a new entity in the main context.
    /// - Parameter configure: Closure to set properties on the new object.
    /// - Returns: The newly inserted object (not yet persisted until save()).
    @discardableResult
    func create(configure: (Entity) -> Void) -> Entity {
        let newObject = Entity(context: viewContext)
        configure(newObject)
        return newObject
    }
    
    // MARK: delete(_:)
    /// Delete a given object from the main context.
    func delete(_ object: Entity) {
        viewContext.delete(object)
    }
    
    // MARK: deleteAll(predicate:)
    /// Batch delete all matching the predicate. Performs on a background context for safety.
    func deleteAll(predicate: NSPredicate? = nil) throws {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: Entity.self))
        fetchRequest.predicate = predicate
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        deleteRequest.resultType = .resultTypeObjectIDs
        
        let context = stack.container.newBackgroundContext()
        let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
        if let objectIDs = result?.result as? [NSManagedObjectID] {
            let changes: [AnyHashable: Any] = [NSDeletedObjectsKey: objectIDs]
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [viewContext])
        }
    }
    
    // MARK: saveIfNeeded()
    /// Save the main context if it has changes.
    func saveIfNeeded() throws {
        guard viewContext.hasChanges else { return }
        try viewContext.save()
    }
    
    // MARK: performBackgroundTask(_:)
    /// Run work on a background context and save if there were changes.
    /// - Parameter work: Closure with a background context.
    func performBackgroundTask(_ work: @escaping (NSManagedObjectContext) throws -> Void) {
        stack.container.performBackgroundTask { ctx in
            ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            do {
                try work(ctx)
                if ctx.hasChanges { try ctx.save() }
            } catch {
                assertionFailure("❌ Background task failed: \(error)")
            }
        }
    }
}
