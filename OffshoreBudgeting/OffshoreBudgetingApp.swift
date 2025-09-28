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
        UITestDataSeeder.applyIfNeeded()
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

    private var shouldApplyThemeTint: Bool {
#if os(macOS)
        return !platformCapabilities.supportsOS26Translucency
#else
        return true
#endif
    }

    var body: some Scene {
        WindowGroup {
            ResponsiveLayoutReader { _ in
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
                // Apply the selected theme's accent color to all controls only
                // when the platform still relies on explicit tint overrides.
                .ub_themeAccentColor(themeManager.selectedTheme.resolvedTint, when: shouldApplyThemeTint)
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
