//
//  PresetsView.swift
//  SoFar
//
//  Created by Michael Brown on 8/11/25.
//

import SwiftUI
import CoreData

// MARK: - PresetsView
/// Displays global (template) Planned Expenses with planned/actual amounts,
/// assigned budget count, and the next upcoming date. Empty state uses
/// UBEmptyState for a consistent look.
struct PresetsView: View {
    // MARK: Dependencies
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var themeManager: ThemeManager

    // MARK: State
    @StateObject private var viewModel = PresetsViewModel()
    @State private var isPresentingAddSheet = false
    @State private var sheetTemplateToAssign: PlannedExpense? = nil
    @State private var editingTemplate: PlannedExpense? = nil
    @State private var templateToDelete: PlannedExpense? = nil
    @AppStorage(AppSettingsKeys.confirmBeforeDelete.rawValue) private var confirmBeforeDelete: Bool = true

    // MARK: Body
    var body: some View {
        // Avoid nesting a List inside an outer ScrollView to prevent
        // jank/freezes on iOS 26. Let the List own scrolling by disabling
        // the scaffold's automatic wrapping.
        RootTabPageScaffold(spacing: DS.Spacing.s, wrapsContentInScrollView: false) {
            RootViewTopPlanes(title: "Presets", titleDisplayMode: .hidden) {
                addPresetButton
            }
        } content: { proxy in
            content(using: proxy)
        }
        .alert(item: $templateToDelete) { template in
            Alert(
                title: Text("Delete \(template.descriptionText ?? "Preset")?"),
                message: Text("This will remove the preset and its assignments."),
                primaryButton: .destructive(Text("Delete")) {
                    delete(template: template)
                },
                secondaryButton: .cancel()
            )
        }
    }

    @ViewBuilder
    private func content(using proxy: RootTabPageProxy) -> some View {
        Group {
            // MARK: Empty State — standardized with UBEmptyState (same as Home/Cards)
            if viewModel.items.isEmpty {
                UBEmptyState(
                    iconSystemName: "list.bullet.rectangle",
                    title: "Presets",
                    message: "Presets are recurring expenses you have every month. Add them here so budgets are faster to create.",
                    primaryButtonTitle: "Add Preset",
                    onPrimaryTap: { isPresentingAddSheet = true }
                )
                .padding(.horizontal, DS.Spacing.l)
                .frame(maxWidth: .infinity)
                .frame(minHeight: proxy.availableHeightBelowHeader, alignment: .center)
            } else {
                // MARK: Non-empty List
                List {
                    ForEach(viewModel.items) { item in
                        PresetRowView(
                            item: item,
                            onAssignTapped: { template in
                                sheetTemplateToAssign = template
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                        .ub_preOS26ListRowBackground(themeManager.selectedTheme.secondaryBackground)
                        .unifiedSwipeActions(
                            onEdit: { editingTemplate = item.template },
                            onDelete: {
                                if confirmBeforeDelete {
                                    templateToDelete = item.template
                                } else {
                                    delete(template: item.template)
                                }
                            }
                        )
                    }
                    .onDelete { indexSet in
                        let targets = indexSet.compactMap { viewModel.items[safe: $0]?.template }
                        if confirmBeforeDelete, let first = targets.first {
                            templateToDelete = first
                        } else {
                            targets.forEach(delete(template:))
                        }
                    }
                }
                .ub_listStyleLiquidAware()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .rootTabContentPadding(
            proxy,
            horizontal: 0,
            includeSafeArea: false,
            tabBarGutter: proxy.compactAwareTabBarGutter
        )
        // MARK: Data lifecycle
        .onAppear { viewModel.loadTemplates(using: viewContext) }
        // Refresh when the data store saves. Observing this coalesced event
        // avoids UI thrash that can occur when listening to
        // NSManagedObjectContextObjectsDidChange directly on newer OSes.
        .onReceive(
            NotificationCenter.default.publisher(for: .dataStoreDidChange)
                .receive(on: RunLoop.main)
        ) { _ in
            viewModel.loadTemplates(using: viewContext)
        }
        // Pull to refresh to force reload of templates
        .refreshable { viewModel.loadTemplates(using: viewContext) }
        // MARK: Add Preset Sheet
        .sheet(isPresented: $isPresentingAddSheet) {
            AddGlobalPlannedExpenseSheet(onSaved: {
                viewModel.loadTemplates(using: viewContext)
            })
            .environment(\.managedObjectContext, viewContext)
            .applyDetentsIfAvailable(detents: [.medium, .large], selection: nil)
        }
        // MARK: Assign Budgets Sheet
        .sheet(item: $sheetTemplateToAssign) { template in
            PresetBudgetAssignmentSheet(template: template) {
                viewModel.loadTemplates(using: viewContext)
            }
            .environment(\.managedObjectContext, viewContext)
            .applyDetentsIfAvailable(detents: [.medium, .large], selection: nil)
        }
        // MARK: Edit Template Sheet
        .sheet(item: $editingTemplate) { template in
            AddPlannedExpenseView(
                plannedExpenseID: template.objectID,
                preselectedBudgetID: nil,
                defaultSaveAsGlobalPreset: true,
                onSaved: {
                    viewModel.loadTemplates(using: viewContext)
                }
            )
            .environment(\.managedObjectContext, viewContext)
        }
        .ub_tabNavigationTitle("Presets")
    }

    private var addPresetButton: some View {
        RootHeaderIconActionButton(
            systemImage: "plus",
            accessibilityLabel: "Add Preset Planned Expense"
        ) {
            isPresentingAddSheet = true
        }
    }

    // MARK: - Actions

    /// Deletes selected global templates (and their children).
    /// - Parameter indexSet: indices from the List.
    private func delete(template: PlannedExpense) {
        do {
            try PlannedExpenseService.shared.deleteTemplateAndChildren(template: template, in: viewContext)
            viewModel.loadTemplates(using: viewContext)
        } catch {
            AppLog.ui.error("PresetsView delete error: \(String(describing: error))")
            viewContext.rollback()
        }
    }
}

// MARK: - AddGlobalPlannedExpenseSheet
/// Presents your AddPlannedExpenseView with our desired defaults for Presets.
/// Important: `defaultSaveAsGlobalPreset` is true so the toggle starts ON.
private struct AddGlobalPlannedExpenseSheet: View {
    // MARK: Callbacks
    let onSaved: () -> Void

    // MARK: Env
    @Environment(\.dismiss) private var dismiss

    // MARK: Body
    var body: some View {
        AddPlannedExpenseView(
            preselectedBudgetID: nil,
            defaultSaveAsGlobalPreset: true,   // <-- default ON when adding from Presets
            showAssignBudgetToggle: true,
            onSaved: {
                onSaved()
                dismiss()
            }
        )
    }
}

// MARK: - Array Safe Indexing
private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// ============================================================================
// MARK: - ViewModel + Helpers
// ============================================================================

// MARK: - PresetListItem
/// Row view model for a global PlannedExpense template.
/// Use this for list rendering; keeps formatting & derived fields separate.
struct PresetListItem: Identifiable, Equatable {
    // MARK: Identity
    let id: UUID
    let template: PlannedExpense

    // MARK: Display
    let name: String
    let plannedAmount: Double
    let actualAmount: Double
    let assignedCount: Int
    let nextDate: Date?

    // MARK: Formatting Helpers
    var plannedCurrency: String { CurrencyFormatter.shared.string(plannedAmount) }
    var actualCurrency: String { CurrencyFormatter.shared.string(actualAmount) }
    var nextDateLabel: String {
        guard let d = nextDate else { return "Complete" }
        return DateFormatterCache.shared.mediumDate(d)
    }

    // MARK: Init
    init(template: PlannedExpense,
         plannedAmount: Double,
         actualAmount: Double,
         assignedCount: Int,
         nextDate: Date?) {
        self.id = template.id ?? UUID()
        self.template = template
        self.name = template.descriptionText ?? "Untitled"
        self.plannedAmount = plannedAmount
        self.actualAmount = actualAmount
        self.assignedCount = assignedCount
        self.nextDate = nextDate
    }
}

// MARK: - PresetsViewModel
/// Loads global PlannedExpense templates and composes row items.
@MainActor
final class PresetsViewModel: ObservableObject {
    // MARK: Published
    @Published private(set) var items: [PresetListItem] = []

    // MARK: API
    /// Fetches global templates, deriving assignment counts and next dates.
    func loadTemplates(using context: NSManagedObjectContext) {
        // Perform fetches off the main thread to avoid UI stalls when the
        // dataset grows. Results are published back on the main actor.
        let bg = CoreDataService.shared.newBackgroundContext()
        Task {
            // Background outline to avoid crossing thread boundaries with
            // managed objects.
            struct Outline {
                let id: NSManagedObjectID
                let name: String
                let planned: Double
                let actual: Double
                let assignedCount: Int
                let nextDate: Date?
            }

            let outlines = await bg.perform { () -> [Outline] in
                let templates = PlannedExpenseService.shared.fetchGlobalTemplates(in: bg)

            let referenceDate = Calendar.current.startOfDay(for: Date())

                var rows: [Outline] = []
                for t in templates {
                    let children = PlannedExpenseService.shared.fetchChildren(of: t, in: bg)

                    let planned = t.plannedAmount
                    let actual = t.actualAmount
                    let assignedCount = children.count

                    var upcomingDates: [Date] = children
                        .compactMap { $0.transactionDate }
                        .filter { $0 >= referenceDate }
                    if let templateDate = t.transactionDate, templateDate >= referenceDate {
                        upcomingDates.append(templateDate)
                    }
                    let nextDate = upcomingDates.min()

                    let name = t.descriptionText ?? "Untitled"
                    rows.append(Outline(id: t.objectID, name: name, planned: planned, actual: actual, assignedCount: assignedCount, nextDate: nextDate))
                }
                return rows
            }

            // Map outlines to PresetListItem on the main actor using the
            // viewContext to re-resolve objects for swipe actions and editing.
            await MainActor.run {
                var built: [PresetListItem] = []
                for o in outlines {
                    if let template = try? context.existingObject(with: o.id) as? PlannedExpense {
                        built.append(
                            PresetListItem(
                                template: template,
                                plannedAmount: o.planned,
                                actualAmount: o.actual,
                                assignedCount: o.assignedCount,
                                nextDate: o.nextDate
                            )
                        )
                    }
                }
                self.items = built.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            }
        }
    }
}

// MARK: - CurrencyFormatter (local, lightweight)
final class CurrencyFormatter {
    static let shared = CurrencyFormatter()
    private let nf: NumberFormatter

    private init() {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        nf = f
    }

    func string(_ value: Double) -> String {
        nf.string(from: NSNumber(value: value)) ?? "$0.00"
    }
}

// MARK: - DateFormatterCache (local helpers)
final class DateFormatterCache {
    static let shared = DateFormatterCache()
    private let medium: DateFormatter

    private init() {
        let m = DateFormatter()
        m.dateStyle = .medium
        m.timeStyle = .none
        medium = m
    }

    func mediumDate(_ date: Date) -> String {
        medium.string(from: date)
    }
}

// MARK: - Availability Helpers
private extension View {
    /// Hides list background on supported OS versions; no-ops on older targets.
    @ViewBuilder
    func applyIfAvailableScrollContentBackgroundHidden() -> some View {
        if #available(iOS 16.0, macCatalyst 16.0, *) {
            scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}
