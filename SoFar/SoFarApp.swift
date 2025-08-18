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
                .tint(themeManager.selectedTheme.accent)
                .preferredColorScheme(themeManager.selectedTheme.colorScheme)
        }
    }
}
