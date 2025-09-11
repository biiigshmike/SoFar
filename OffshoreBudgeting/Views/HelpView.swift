import SwiftUI

/// Comprehensive in-app guide that mirrors the app's documented structure.
/// Each section pulls from `// MARK:` comments across the codebase so users can
/// explore the same hierarchy developers see.
struct HelpView: View {
    var body: some View {
        NavigationStack {
            List {
                // MARK: Getting Started
                Section("Getting Started") {
                    NavigationLink("Introduction") { intro }
                    NavigationLink("Onboarding") { onboarding }
                }

                // MARK: Core Screens
                Section("Core Screens") {
                    NavigationLink("Home") { home }
                    NavigationLink("Income") { income }
                    NavigationLink("Cards") { cards }
                    NavigationLink("Presets") { presets }
                    NavigationLink("Settings") { settings }
                }

                // MARK: Tips & Tricks
                Section("Tips & Tricks") {
                    NavigationLink("Shortcuts & Gestures") { tips }
                }
            }
            .navigationTitle("Help")
        }
        .frame(minWidth: 400, minHeight: 500)
    }

    // MARK: - Pages

    private var intro: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Welcome to Offshore Budgeting! This guide highlights the app's major areas so you can quickly build budgets, track income, and log expenses across platforms.")
            }
            .padding()
            .navigationTitle("Introduction")
        }
    }

    private var onboarding: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("When launching the app for the first time, a five-step onboarding flow sets up your workspace:")
                Text("• Welcome screen")
                Text("• Create initial expense categories")
                Text("• Add cards used for spending")
                Text("• Add preset planned expenses")
                Text("• Final loading step that unlocks the main interface")
                Text("You can replay this flow from Settings → Onboarding.")
            }
            .padding()
            .navigationTitle("Onboarding")
        }
    }

    private var home: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("The Home tab combines a period header with a content area:")
                Text("• Use the chevron buttons or calendar menu to navigate months or change the budget period.")
                Text("• If no budget exists for the selected period, an empty state prompts you to create one.")
                Text("• Existing budgets reveal full details via `BudgetDetailsView` where you can edit or delete the budget from the toolbar menu.")
                Text("• Pull to refresh or let changes propagate automatically when Core Data updates.")
            }
            .padding()
            .navigationTitle("Home")
        }
    }

    private var income: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Track paychecks and other revenue on a calendar:")
                Text("• Weeks start on Sunday and today's date is highlighted to match the current theme.")
                Text("• Tap a day to show its entries beneath the calendar.")
                Text("• Use the plus button or double‑click a date on macOS to add income with optional recurrence rules.")
                Text("• Swipe an entry to edit or delete; confirmations appear if enabled in Settings.")
                Text("• A weekly summary bar totals income for the visible week.")
                Text("• Pull to refresh to reload entries if needed.")
            }
            .padding()
            .navigationTitle("Income")
        }
    }

    private var cards: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Manage cards and unplanned expenses:")
                Text("• Responsive grid uses stable identities to avoid layout jitter.")
                Text("• Tap a card to select it and reveal detailed spending; tap Done to close the detail view.")
                Text("• The toolbar plus adds a new card, or an expense if a card is selected.")
                Text("• Context menus offer edit and delete actions, and most lists support pull to refresh.")
            }
            .padding()
            .navigationTitle("Cards")
        }
    }

    private var presets: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Presets are reusable planned expense templates:")
                Text("• Each row shows planned/actual amounts, how many budgets use it, and the next upcoming date.")
                Text("• The plus button creates a template with \"Save as Global Preset\" enabled by default.")
                Text("• Swipe to edit or delete, or assign the template to budgets using the Assign button.")
                Text("• The list updates automatically when templates change and supports pull to refresh.")
            }
            .padding()
            .navigationTitle("Presets")
        }
    }

    private var settings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Customize app behavior and manage data:")
                Text("• General: confirm before deleting items and choose the default budget period.")
                Text("• Appearance: select a theme; the accent color tints controls across platforms.")
                Text("• iCloud Services: sync your data, card themes, app theme, and budget period across devices.")
                Text("• Presets: control whether new planned expenses default to future budgets.")
                Text("• Expense Categories: open a manager to create or edit categories for variable expenses.")
                Text("• Onboarding: replay the initial setup flow at any time.")
                Text("• Reset: erase all stored budgets, cards, incomes, and expenses.")
                Text("• Help: on iOS and iPadOS you can open this guide from Settings → Help.")
            }
            .padding()
            .navigationTitle("Settings")
        }
    }

    private var tips: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Power-user hints:")
                Text("• Press ⌘? on macOS to open this help window.")
                Text("• Double‑click a date in the Income calendar on macOS to create an entry instantly.")
                Text("• Most lists support swipe actions for editing or deleting items and pull to refresh for reloading.")
                Text("• Look for tooltips on buttons and menus for additional keyboard shortcuts.")
            }
            .padding()
            .navigationTitle("Shortcuts & Gestures")
        }
    }
}

struct HelpView_Previews: PreviewProvider {
    static var previews: some View {
        HelpView()
    }
}

