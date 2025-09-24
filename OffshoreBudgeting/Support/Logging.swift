import Foundation
import os

/// Centralized, lightweight logging wrapper.
/// Usage: `AppLog.coreData.info("message")`
enum AppLog {
    static let subsystem = Bundle.main.bundleIdentifier ?? "OffshoreBudgeting"

    // Categories
    static let coreData = Logger(subsystem: subsystem, category: "CoreData")
    static let iCloud   = Logger(subsystem: subsystem, category: "iCloud")
    static let service  = Logger(subsystem: subsystem, category: "Service")
    static let viewModel = Logger(subsystem: subsystem, category: "ViewModel")
    static let ui       = Logger(subsystem: subsystem, category: "UI")

    // Verbosity toggle (UserDefaults-backed)
    private static let verboseKey = "AppLog.verbose"

    static var isVerbose: Bool {
        get { UserDefaults.standard.bool(forKey: verboseKey) }
        set { UserDefaults.standard.set(newValue, forKey: verboseKey) }
    }

    /// Convenience API for flipping verbosity at runtime.
    static func setVerbose(_ enabled: Bool) { isVerbose = enabled }
}
