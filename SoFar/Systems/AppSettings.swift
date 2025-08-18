import Foundation

// MARK: - AppSettingsKeys
/// Keys for storing user preferences in UserDefaults.
/// Defaults for new keys are `true` so features are enabled out of the box.
enum AppSettingsKeys: String {
    case confirmBeforeDelete
    case enableHaptics
    case calendarHorizontal
    case presetsDefaultUseInFutureBudgets
    case syncCardThemes
    case syncAppTheme
    case enableCloudSync
}
