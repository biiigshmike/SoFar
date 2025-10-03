import Foundation
import CoreData
import Testing
@testable import Offshore

enum TestUtils {
    // MARK: - Calendar
    static func utcCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    static func makeDate(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = y
        comps.month = m
        comps.day = d
        comps.hour = h
        comps.minute = min
        comps.timeZone = TimeZone(secondsFromGMT: 0)
        return Calendar(identifier: .gregorian).date(from: comps) ?? Date.distantPast
    }

    // MARK: - Core Data
    @discardableResult
    static func resetStore(timeout: TimeInterval = 10.0) throws -> NSPersistentContainer {
        let service = CoreDataService.shared
        let container = service.container
        let coordinator = container.persistentStoreCoordinator

        // Ensure the persistent stores are attached (synchronously) for tests
        if coordinator.persistentStores.isEmpty {
            let sema = DispatchSemaphore(value: 0)
            var loadError: Error?
            container.loadPersistentStores { _, error in
                loadError = error
                sema.signal()
            }
            _ = sema.wait(timeout: .now() + timeout)
            if let loadError { throw loadError }
        }

        // Clean slate per test run
        try service.wipeAllData()
        return container
    }
}
