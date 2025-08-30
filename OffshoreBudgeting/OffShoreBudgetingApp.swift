//
//  SoFarApp.swift
//  SoFar
//
//  Created by Michael Brown on 8/11/25.
//

import SwiftUI

@main
struct SoFarApp: App {
    // MARK: Dependencies
    @StateObject private var themeManager = ThemeManager()

    // MARK: Onboarding State
    /// Persisted flag indicating whether the intro flow has been completed.
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    // MARK: Init
    init() {
        CoreDataService.shared.ensureLoaded()
    }

    // MARK: Body
    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    RootTabView()
                } else {
                    OnboardingFlowView {
                        hasCompletedOnboarding = true
                    }
                }
            }
            .environment(\.managedObjectContext, CoreDataService.shared.viewContext)
            .environmentObject(themeManager)
            // Apply the selected theme's accent color to all controls.
            // `tint` covers most modern SwiftUI controls, while `accentColor`
            // is still required for some AppKit-backed macOS components
            // (e.g., checkboxes, date pickers) to respect the theme.
            .accentColor(themeManager.selectedTheme.accent)
            .tint(themeManager.selectedTheme.accent)
            .preferredColorScheme(themeManager.selectedTheme.colorScheme)
            #if os(macOS)
            .frame(minWidth: 800, minHeight: 600)
            #endif
        }
        #if os(macOS)
        .defaultSize(width: 1000, height: 800)
        #endif
    }
}
