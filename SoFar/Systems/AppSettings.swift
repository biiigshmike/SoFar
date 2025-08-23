import Foundation

// MARK: - AppSettingsKeys
/// Keys for storing user preferences in UserDefaults.
/// Defaults for new keys are `true` so features are enabled out of the box.
enum AppSettingsKeys: String {
    case confirmBeforeDelete
    case calendarHorizontal
    case presetsDefaultUseInFutureBudgets
    case budgetPeriod
    case syncCardThemes
    case syncAppTheme
    case syncBudgetPeriod
    case enableCloudSync
    case showHints
    case completedAppTour
}
