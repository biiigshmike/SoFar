//
//  CoreDataService.swift
//  SoFar
//
//  Created by Michael Brown on 8/11/25.
//

import Foundation
import CoreData

// MARK: - CoreDataService
/// Centralized Core Data stack configured for local-only storage.
/// iCloud/CloudKit mirroring is disabled to simplify testing and UI work.
final class CoreDataService: ObservableObject {

    // MARK: Singleton
    static let shared = CoreDataService()

    private let notificationCenter: NotificationCentering

    private init(notificationCenter: NotificationCentering = NotificationCenterAdapter.shared) {
        self.notificationCenter = notificationCenter
    }
    
    // MARK: Configuration
    /// Name of the .xcdatamodeld file (without extension).
    /// IMPORTANT: Ensure your model is named "SoFarModel.xcdatamodeld".
    private let modelName = "OffshoreBudgetingModel"
    
    /// CloudKit sync is disabled in this build.
    private var enableCloudKitSync: Bool { false }

    private var loadingTask: Task<Void, Never>?
    
    // MARK: Load State
    /// Tracks whether persistent stores have been loaded at least once.
    private(set) var storesLoaded: Bool = false

    // MARK: Change Observers
    /// Observers for Core Data saves and remote changes that trigger view updates.
    private var didSaveObserver: NSObjectProtocol?
    private var remoteChangeObserver: NSObjectProtocol?
    private var cloudKitEventObserver: NSObjectProtocol?
    
    // MARK: Persistent Container
    /// Expose the container as NSPersistentContainer (local-only).
    public lazy var container: NSPersistentContainer = {
        let container = NSPersistentContainer(name: modelName)
        
        // Store location
        let storeURL = NSPersistentContainer.defaultDirectoryURL()
            .appendingPathComponent("\(modelName).sqlite")
        let description = NSPersistentStoreDescription(url: storeURL)
        
        // MARK: Store Options
        // Keep these ON consistently to avoid "previously opened with X, now without X" read-only issues.
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        // Remote change notifications are only relevant for CloudKit setups.
        // Keep this OFF to avoid spurious notifications/infinite refresh loops.
        description.setOption(false as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        
        // No CloudKit options; local-only store.
        
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

        if loadingTask != nil { return }

        loadingTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.loadStores(file: file, line: line)
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

        // Begin monitoring Core Data saves.
        startObservingChanges()
    }

    // MARK: Change Observation
    /// Listens for context saves and posts a unified `.dataStoreDidChange`
    /// notification so views can react centrally.
    private func startObservingChanges() {
        // Avoid duplicate observers if called more than once.
        if didSaveObserver != nil { return }

        let center = notificationCenter

        didSaveObserver = center.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: .main
        ) { _ in
            center.post(name: .dataStoreDidChange, object: nil)
        }

        // Remote change observation is disabled in local-only mode.
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
    /// Suspends until `storesLoaded` is true. Optionally provide a timeout to
    /// prevent indefinite waiting when debugging store configuration issues.
    func waitUntilStoresLoaded(timeout: TimeInterval? = nil, pollInterval: TimeInterval = 0.05) async {
        if storesLoaded { return }
        ensureLoaded()

        let start = Date()
        while !storesLoaded {
            if Task.isCancelled { return }

            if let timeout, Date().timeIntervalSince(start) >= timeout {
                if AppLog.isVerbose {
                    AppLog.coreData.info("waitUntilStoresLoaded() timed out after \(timeout)s while awaiting persistent stores")
                }
                return
            }

            try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }
        if AppLog.isVerbose {
            AppLog.coreData.debug("waitUntilStoresLoaded() finished after \(String(format: "%.2f", Date().timeIntervalSince(start)))s")
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

// MARK: - Cloud Sync Preferences

extension CoreDataService {

    /// Applies the user's Cloud Sync preference and reconfigures persistent stores accordingly.
    /// - Parameter enableSync: When `true`, persistent stores rebuild for CloudKit mode; otherwise they revert to local mode.
    @MainActor
    func applyCloudSyncPreferenceChange(enableSync: Bool) async {
        // No-op in local-only builds. Always ensure local mode is active.
        await reconfigurePersistentStoresForLocalMode()
    }
}

// MARK: - Private Helpers

private extension CoreDataService {
    @MainActor
    func loadStores(file: StaticString, line: UInt) async {
        defer { loadingTask = nil }

        do {
            try await loadPersistentStores()

            postLoadConfiguration()
            storesLoaded = true

            let urls = container.persistentStoreCoordinator.persistentStores.compactMap { $0.url }
            let names = urls.map { $0.lastPathComponent }.joined(separator: ", ")
            if AppLog.isVerbose {
                AppLog.coreData.info("Core Data stores loaded (\(urls.count)): \(names)")
            }
        } catch {
            let nsError = error as NSError
            fatalError("❌ Core Data failed to load at \(file):\(line): \(nsError), \(nsError.userInfo)")
        }
    }

    func loadPersistentStores() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            container.loadPersistentStores { _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func disableCloudSyncPreferences() {
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: AppSettingsKeys.enableCloudSync.rawValue)
        defaults.set(false, forKey: AppSettingsKeys.syncCardThemes.rawValue)
        defaults.set(false, forKey: AppSettingsKeys.syncAppTheme.rawValue)
        defaults.set(false, forKey: AppSettingsKeys.syncBudgetPeriod.rawValue)
    }

    @MainActor
    func reconfigurePersistentStoresForLocalMode() async {
        await rebuildPersistentStores(for: .local)
    }

    private enum PersistentStoreMode: Equatable {
        case local

        var logDescription: String {
            switch self {
            case .local:
                return "local mode"
            }
        }
    }

    @MainActor
    private func rebuildPersistentStores(for mode: PersistentStoreMode) async {
        guard let description = container.persistentStoreDescriptions.first else { return }

        let currentMode: PersistentStoreMode
        currentMode = .local

        if currentMode == mode, storesLoaded {
            if AppLog.isVerbose {
                AppLog.coreData.debug("Skipping persistent store rebuild – already configured for \(mode.logDescription)")
            }
            return
        }

        loadingTask?.cancel()
        loadingTask = nil

        // Nothing to toggle; always local-only.

        let coordinator = container.persistentStoreCoordinator
        viewContext.reset()

        for store in coordinator.persistentStores {
            do {
                try coordinator.remove(store)
            } catch {
                assertionFailure("❌ Failed to detach persistent store: \(error)")
            }
        }

        storesLoaded = false

        do {
            try await loadPersistentStores()
            postLoadConfiguration()
            storesLoaded = true
            notificationCenter.post(name: .dataStoreDidChange, object: nil)
            if AppLog.isVerbose {
                AppLog.coreData.info("Rebuilt persistent stores for \(mode.logDescription)")
            }
        } catch {
            assertionFailure("❌ Failed to rebuild persistent stores for \(mode.logDescription): \(error)")
        }
    }
}
