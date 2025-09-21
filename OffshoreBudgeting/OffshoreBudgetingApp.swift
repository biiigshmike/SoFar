//
//  OffshoreBudgetingApp.swift
//  OffshoreBudgeting
//
//  Created by Michael Brown on 8/11/25.
//

import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@main
struct OffshoreBudgetingApp: App {
    // MARK: Dependencies
    @StateObject private var themeManager = ThemeManager()
    private let platformCapabilities = PlatformCapabilities.current
    @Environment(\.colorScheme) private var systemColorScheme
#if os(macOS)
    @Environment(\.openWindow) private var openWindow
#endif
    
    // MARK: Onboarding State
    /// Persisted flag indicating whether the intro flow has been completed.
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding: Bool = false
    
    // MARK: Init
    init() {
        CoreDataService.shared.ensureLoaded()
        // No macOS-specific setup required at the moment.
#if os(iOS)
        // Reduce the chance of text truncation across the app by allowing
        // UILabel-backed Text views to shrink when space is constrained.
        let labelAppearance = UILabel.appearance()
        labelAppearance.adjustsFontSizeToFitWidth = true
        labelAppearance.minimumScaleFactor = 0.5
        labelAppearance.lineBreakMode = .byClipping
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
            }
            .ub_onChange(of: systemColorScheme) { newScheme in
                themeManager.refreshSystemAppearance(newScheme)
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
        .commands {
            CommandGroup(replacing: .help) {
                Button("Offshore Budgeting Help") {
                    openWindow(id: "help")
                }
                .keyboardShortcut("?", modifiers: .command)
            }
        }
#endif
#if os(macOS)
        Window("Offshore Budgeting Help", id: "help") {
            HelpView()
        }
#endif
    }
}

#if os(iOS) || os(macOS)
private struct ThemedToggleTint: ViewModifier {
    let color: Color

    func body(content: Content) -> some View {
        if #available(iOS 15.0, macOS 12.0, *) {
            content.toggleStyle(SwitchToggleStyle(tint: color))
        } else {
            content
        }
    }
}
#else
private struct ThemedToggleTint: ViewModifier {
    let color: Color

    func body(content: Content) -> some View { content }
}
#endif
