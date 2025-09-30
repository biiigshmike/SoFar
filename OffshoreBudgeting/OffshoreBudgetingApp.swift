//
//  OffshoreBudgetingApp.swift
//  OffshoreBudgeting
//
//  Created by Michael Brown on 8/11/25.
//

import SwiftUI
import UIKit

@main
struct OffshoreBudgetingApp: App {
    // MARK: Dependencies
    @StateObject private var themeManager = ThemeManager()
    private let platformCapabilities = PlatformCapabilities.current
    @Environment(\.colorScheme) private var systemColorScheme

    // MARK: Onboarding State
    /// Persisted flag indicating whether the intro flow has been completed.
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding: Bool = false

    // MARK: Init
    init() {
        CoreDataService.shared.ensureLoaded()
        UITestDataSeeder.applyIfNeeded()
        // No macOS-specific setup required at the moment.
        // Reduce the chance of text truncation across the app by allowing
        // UILabel-backed Text views to shrink when space is constrained.
        let labelAppearance = UILabel.appearance()
        labelAppearance.adjustsFontSizeToFitWidth = true
        labelAppearance.minimumScaleFactor = 0.75
        labelAppearance.lineBreakMode = .byClipping
    }

    var body: some Scene {
        WindowGroup {
            configuredScene {
                ResponsiveLayoutReader { _ in
                    Group {
                        if didCompleteOnboarding {
                            RootTabView()
                        } else {
                            OnboardingView()
                        }
                    }
                }
            }
        }
#if targetEnvironment(macCatalyst)
        .commands {
            CommandGroup(replacing: .help) {
                Button("Offshore Budgeting Help") {
                    requestHelpScene()
                }
                .keyboardShortcut("?", modifiers: .command)
            }
        }
#endif

#if targetEnvironment(macCatalyst)
        WindowGroup(id: catalystHelpSceneIdentifier) {
            configuredScene {
                HelpView()
            }
        }
        .handlesExternalEvents(matching: Set(arrayLiteral: helpActivityType))
#endif
    }

    // MARK: Scene Wiring
    @ViewBuilder
    private func configuredScene<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .environment(\.managedObjectContext, CoreDataService.shared.viewContext)
            .environmentObject(themeManager)
            .environment(\.platformCapabilities, platformCapabilities)
            // Apply the selected theme's accent color to all controls.
            // `tint` covers most modern SwiftUI controls, while `accentColor`
            // is still required for some AppKit-backed macOS components
            // (e.g., checkboxes, date pickers) to respect the theme.
            .accentColor(themeManager.selectedTheme.resolvedTint)
            .tint(themeManager.selectedTheme.resolvedTint)
            .modifier(ThemedToggleTint(color: themeManager.selectedTheme.toggleTint))
            .onAppear {
                themeManager.refreshSystemAppearance(systemColorScheme)
                SystemThemeAdapter.applyGlobalChrome(theme: themeManager.selectedTheme, colorScheme: systemColorScheme)
            }
            .ub_onChange(of: systemColorScheme) { newScheme in
                themeManager.refreshSystemAppearance(newScheme)
                SystemThemeAdapter.applyGlobalChrome(theme: themeManager.selectedTheme, colorScheme: newScheme)
            }
            .ub_onChange(of: themeManager.selectedTheme) {
                SystemThemeAdapter.applyGlobalChrome(theme: themeManager.selectedTheme, colorScheme: systemColorScheme)
            }
    }

#if targetEnvironment(macCatalyst)
    private var helpActivityType: String {
        (Bundle.main.bundleIdentifier ?? "com.offshorebudgeting") + ".help"
    }

    private var catalystHelpSceneIdentifier: String { "help" }

    private func requestHelpScene() {
        let activity = NSUserActivity(activityType: helpActivityType)
        activity.title = "Offshore Budgeting Help"
        UIApplication.shared.requestSceneSessionActivation(nil, userActivity: activity, options: nil, errorHandler: nil)
    }
#endif
}

private struct ThemedToggleTint: ViewModifier {
    let color: Color

    func body(content: Content) -> some View {
        if #available(iOS 15.0, macCatalyst 15.0, *) {
            content.toggleStyle(SwitchToggleStyle(tint: color))
        } else {
            content
        }
    }
}
