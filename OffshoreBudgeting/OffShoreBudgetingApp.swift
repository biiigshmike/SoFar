//
//  SoFarApp.swift
//  SoFar
//
//  Created by Michael Brown on 8/11/25.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

@main
struct SoFarApp: App {
    // MARK: Dependencies
    @StateObject private var themeManager = ThemeManager()
    
    // MARK: Onboarding State
    /// Persisted flag indicating whether the intro flow has been completed.
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding: Bool = false
    
    // MARK: Init
    init() {
        CoreDataService.shared.ensureLoaded()
#if os(macOS)
        // Ensure text fields default to leading alignment on macOS forms.
        // Setting the appearance once at launch avoids focus loss that
        // occurred when toggling alignment dynamically.
        // Use NSTextFieldCell to globally set the default alignment. Using
        // `appearance()` here avoids modifying the alignment while a field is
        // being edited, which previously caused focus to be lost after each
        // keystroke.
        NSTextFieldCell.appearance().alignment = .left
#endif
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
