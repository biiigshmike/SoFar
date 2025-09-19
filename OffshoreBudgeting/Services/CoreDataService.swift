//
//  CoreDataService.swift
//  SoFar
//
//  Created by Michael Brown on 8/11/25.
//

import Foundation
import CoreData

// MARK: - CoreDataService
/// Centralized Core Data stack using NSPersistentCloudKitContainer to allow
/// future CloudKit sync without rewriting the stack. Cloud is OFF by default
/// (no special store options added). We keep history tracking ON to enable
/// responsive UI updates later.
final class CoreDataService: ObservableObject {
    
    // MARK: Singleton
    static let shared = CoreDataService()
    private init() {}
    
    // MARK: Configuration
    /// Name of the .xcdatamodeld file (without extension).
    /// IMPORTANT: Ensure your model is named "SoFarModel.xcdatamodeld".
    private let modelName = "OffshoreBudgetingModel"
    
    /// Determines whether CloudKit-backed sync is enabled via user settings.
    private var enableCloudKitSync: Bool {
        UserDefaults.standard.object(forKey: AppSettingsKeys.enableCloudSync.rawValue) as? Bool ?? false
    }
    
    // MARK: Load State
    /// Tracks whether persistent stores have been loaded at least once.
    private(set) var storesLoaded: Bool = false

    // MARK: Change Observers
    /// Observers for Core Data saves and remote changes that trigger view updates.
    private var didSaveObserver: NSObjectProtocol?
    private var remoteChangeObserver: NSObjectProtocol?
    private var cloudKitEventObserver: NSObjectProtocol?
    
    // MARK: Persistent Container
    /// Expose the container as NSPersistentContainer to satisfy CoreDataStackProviding.
    /// Internally we still build an NSPersistentCloudKitContainer for future sync.
    public lazy var container: NSPersistentContainer = {
        let container = NSPersistentCloudKitContainer(name: modelName)
        
        // Store location
        let storeURL = NSPersistentContainer.defaultDirectoryURL()
            .appendingPathComponent("\(modelName).sqlite")
        let description = NSPersistentStoreDescription(url: storeURL)
        
        // MARK: Store Options
        // Keep these ON consistently to avoid "previously opened with X, now without X" read-only issues.
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        
        // CloudKit (deferred). When you’re ready, we’ll set:
        // description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.mbrown.offshore)
        // and ensure entitlements are set up. For now, leave it nil.
        if enableCloudKitSync {
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.mbrown.offshore")
        }
        
        container.persistentStoreDescriptions = [description]
        return container
    }()
    
    // MARK: Contexts
    /// Main thread context for UI work.
    public var viewContext: NSManagedObjectContext {
        container.viewContext
    }
    
    /// Background context (on-demand) for write-heavy operations.
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        return context
    }
    
    // MARK: Lifecycle
    /// Preferred: call this once during app launch. Safe to call multiple times.
    func ensureLoaded(file: StaticString = #file, line: UInt = #line) {
        guard !storesLoaded else { return }
        container.loadPersistentStores { [weak self] _, error in
            if let error = error as NSError? {
                fatalError("❌ Core Data failed to load at \(file):\(line): \(error), \(error.userInfo)")
            } else {
                self?.postLoadConfiguration()
                self?.storesLoaded = true
                #if DEBUG
                let urls = self?.container.persistentStoreCoordinator.persistentStores.compactMap { $0.url } ?? []
                print("✅ Core Data stores loaded (\(urls.count)):", urls)
                #endif
            }
        }
    }
    
    /// Backwards-compat alias for older call sites.
    func loadPersistentStores() {
        ensureLoaded()
    }
    
    // MARK: Post-Load Configuration
    /// Configure viewContext behaviors after stores load.
    private func postLoadConfiguration() {
        // Merge changes from background contexts so UI updates automatically.
        viewContext.automaticallyMergesChangesFromParent = true
        // You had StoreTrump; keeping your choice here.
        viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        // Optional: performance niceties
        viewContext.undoManager = nil

        // Begin monitoring Core Data saves and remote changes.
        startObservingChanges()

        if enableCloudKitSync {
            startObservingCloudKitEvents()
        } else {
            stopObservingCloudKitEvents()
        }
    }

    // MARK: Change Observation
    /// Listens for context saves and remote store changes and posts a unified
    /// `.dataStoreDidChange` notification so views can react centrally.
    private func startObservingChanges() {
        // Avoid duplicate observers if called more than once.
        if didSaveObserver != nil || remoteChangeObserver != nil { return }

        didSaveObserver = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: .main
        ) { _ in
            NotificationCenter.default.post(name: .dataStoreDidChange, object: nil)
        }

        remoteChangeObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator,
            queue: .main
        ) { _ in
            NotificationCenter.default.post(name: .dataStoreDidChange, object: nil)
        }
    }

    // MARK: CloudKit Event Observation
    /// Watches for CloudKit setup issues so we can disable sync automatically
    /// instead of logging noisy errors when the user signs out or switches
    /// iCloud accounts.
    private func startObservingCloudKitEvents() {
        guard cloudKitEventObserver == nil else { return }

        cloudKitEventObserver = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: container,
            queue: .main
        ) { [weak self] note in
            guard
                let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event
            else {
                return
            }

            self?.handleCloudKitEvent(event)
        }
    }

    private func stopObservingCloudKitEvents() {
        if let observer = cloudKitEventObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        cloudKitEventObserver = nil
    }

    private func handleCloudKitEvent(_ event: NSPersistentCloudKitContainer.Event) {
        // Some SDK versions (older iOS/macOS deployment targets) don't expose the
        // newer `.setupDidFail`/`.accountChange` cases on `EventType`. Instead of
        // relying on the case we detect the well-known account change error and
        // respond to it uniformly.
        guard let error = event.error as NSError? else { return }
        guard error.domain == NSCocoaErrorDomain, error.code == 134405 else { return }

        stopObservingCloudKitEvents()

        let defaults = UserDefaults.standard
        defaults.set(false, forKey: AppSettingsKeys.enableCloudSync.rawValue)
        defaults.set(false, forKey: AppSettingsKeys.syncCardThemes.rawValue)
        defaults.set(false, forKey: AppSettingsKeys.syncAppTheme.rawValue)
        defaults.set(false, forKey: AppSettingsKeys.syncBudgetPeriod.rawValue)

        #if DEBUG
        print("⚠️ Cloud sync disabled after detecting an iCloud account change. Error: \(error)")
        #endif
    }
    
    // MARK: Save
    /// Saves the main context if there are changes. Call from the main thread.
    /// - Throws: Propagates save errors for calling site to handle (or convert to alerts).
    func saveIfNeeded() throws {
        // Defensive: make sure at least one store is attached
        let hasStores = !(viewContext.persistentStoreCoordinator?.persistentStores.isEmpty ?? true)
        guard hasStores else {
            throw NSError(domain: "SoFar.CoreData", code: 1001, userInfo: [
                NSLocalizedDescriptionKey: "Persistent stores are not loaded. Call CoreDataService.shared.ensureLoaded() at app launch."
            ])
        }
        guard viewContext.hasChanges else { return }
        try viewContext.save()
    }
    
    // MARK: Background Task
    /// Performs a write on a background context and saves it.
    /// - Parameter work: Closure with the background context to perform your writes.
    func performBackgroundTask(_ work: @escaping (NSManagedObjectContext) throws -> Void) {
        container.performBackgroundTask { context in
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            context.automaticallyMergesChangesFromParent = true
            do {
                try work(context)
                if context.hasChanges {
                    try context.save()
                }
            } catch {
                assertionFailure("❌ Background task failed: \(error)")
            }
        }
    }

    // MARK: Await Stores Loaded (Tiny helper)
    /// Suspends until `storesLoaded` is true (or a short timeout elapses).
    /// Use this before first fetches that must succeed immediately after launch.
    func waitUntilStoresLoaded(timeout: TimeInterval = 3.0, pollInterval: TimeInterval = 0.05) async {
        if storesLoaded { return }
        ensureLoaded()
        let deadline = Date().addingTimeInterval(timeout)
        while !storesLoaded && Date() < deadline {
            try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }
    }

    // MARK: - Reset
    /// Completely remove all data from the persistent store.
    func wipeAllData() throws {
        let context = viewContext
        try context.performAndWait {
            for entity in container.managedObjectModel.entities {
                guard let name = entity.name else { continue }
                let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: name)
                let request = NSBatchDeleteRequest(fetchRequest: fetch)
                try context.execute(request)
            }
            try context.save()
        }
    }
}
