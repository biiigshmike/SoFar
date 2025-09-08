//
//  OffshoreBudgetingApp.swift
//  OffshoreBudgeting
//
//  Created by Michael Brown on 8/11/25.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

@main
struct OffshoreBudgetingApp: App {
    // MARK: Dependencies
    @StateObject private var themeManager = ThemeManager()
    @Environment(\.colorScheme) private var systemColorScheme
    
    // MARK: Onboarding State
    /// Persisted flag indicating whether the intro flow has been completed.
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding: Bool = false
    
    // MARK: Init
    init() {
        CoreDataService.shared.ensureLoaded()
        // No macOS-specific setup required at the moment.
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if didCompleteOnboarding {
                    RootTabView()
                    //OnboardingView()
                } else {
                    OnboardingView()
                    //RootTabView()
                }
            }
            .environment(\.managedObjectContext, CoreDataService.shared.viewContext)
            .environmentObject(themeManager)
            // Apply the selected theme's accent color to all controls.
            // `tint` covers most modern SwiftUI controls, while `accentColor`
            // is still required for some AppKit-backed macOS components
            // (e.g., checkboxes, date pickers) to respect the theme.
            .accentColor(themeManager.selectedTheme.tint)
            .tint(themeManager.selectedTheme.tint)
            // Allow text to shrink and wrap as needed across all display sizes
            .lineLimit(nil)
            .minimumScaleFactor(0.75)
            .onAppear {
                themeManager.refreshSystemAppearance(systemColorScheme)
            }
            .onChange(of: systemColorScheme) {
                themeManager.refreshSystemAppearance(systemColorScheme)
            }
#if os(macOS)
            // Ensure macOS text fields default to leading alignment without
            // dynamically toggling it during editing, which can steal focus.
            .multilineTextAlignment(.leading)
#endif
#if os(macOS)
            .frame(minWidth: 800, minHeight: 600)
#endif
        }
#if os(macOS)
        .defaultSize(width: 1000, height: 800)
#endif
    }
}
