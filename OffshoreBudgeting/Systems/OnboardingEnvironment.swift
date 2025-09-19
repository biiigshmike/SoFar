import SwiftUI

/// Indicates that a view hierarchy is being presented inside the onboarding
/// flow. Views can read this environment value to adapt their styling so that
/// buttons, backgrounds, and layout density feel cohesive with the rest of the
/// intro experience.
struct OnboardingPresentationKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    /// Flag describing whether the current view is shown as part of the
    /// onboarding experience.
    var isOnboardingPresentation: Bool {
        get { self[OnboardingPresentationKey.self] }
        set { self[OnboardingPresentationKey.self] = newValue }
    }
}

extension View {
    /// Marks the current view hierarchy as being shown from within the
    /// onboarding flow so child views can unify their styling.
    /// - Parameter isOnboarding: Pass `true` to enable onboarding-specific
    ///   styling adjustments (default is `true`).
    /// - Returns: A view with the environment value applied.
    func onboardingPresentation(_ isOnboarding: Bool = true) -> some View {
        environment(\.isOnboardingPresentation, isOnboarding)
    }
}
