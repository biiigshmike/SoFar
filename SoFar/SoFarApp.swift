//
//  SoFarApp.swift
//  SoFar
//
//  Created by Michael Brown on 8/11/25.
//

import SwiftUI

@main
struct SoFarApp: App {
    @StateObject private var themeManager = ThemeManager()

    init() {
        CoreDataService.shared.ensureLoaded()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(\.managedObjectContext, CoreDataService.shared.viewContext)
                .environmentObject(themeManager)
                // Apply the selected theme's accent color to all controls.
                // `tint` covers most modern SwiftUI controls, while `accentColor`
                // is still required for some AppKit-backed macOS components
                // (e.g., checkboxes, date pickers) to respect the theme.
                .accentColor(themeManager.selectedTheme.accent)
                .tint(themeManager.selectedTheme.accent)
                .preferredColorScheme(themeManager.selectedTheme.colorScheme)
        }
    }
}
