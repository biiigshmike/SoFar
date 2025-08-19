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

    // MARK: Body
    var body: some View {
        NavigationStack {
            Group {
                // MARK: Empty State — standardized with UBEmptyState (same as Home/Cards)
                if viewModel.items.isEmpty {
                    UBEmptyState(
                        iconSystemName: "list.bullet.rectangle",
                        title: "Presets",
                        message: "Create a preset planned expense to reuse across budgets.",
                        primaryButtonTitle: "Add Preset",
                        onPrimaryTap: { isPresentingAddSheet = true }
                    )
                    .padding(.horizontal, DS.Spacing.l)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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
                            .listRowBackground(themeManager.selectedTheme.secondaryBackground)
                            .unifiedSwipeActions(
                                UnifiedSwipeConfig(editTint: themeManager.selectedTheme.secondaryAccent),
                                onEdit: { editingTemplate = item.template },
                                onDelete: { delete(template: item.template) }
                            )
                        }
                        .onDelete(perform: deleteTemplates(_:))
                    }
                    .listStyle(.plain)
                    .applyIfAvailableScrollContentBackgroundHidden()
                }
            }
            .navigationTitle("Presets")
            // MARK: App Toolbar (pill +) — same pattern used on Home/Cards
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isPresentingAddSheet = true
                    } label: {
                        Label("Add Preset Planned Expense", systemImage: "plus")
                    }
                }
            }
            // MARK: Data lifecycle
            .onAppear { viewModel.loadTemplates(using: viewContext) }
            .onReceive(
                NotificationCenter.default
                    .publisher(for: .NSManagedObjectContextObjectsDidChange)
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
                .presentationDetents([.medium, .large])
            }
            // MARK: Assign Budgets Sheet
            .sheet(item: $sheetTemplateToAssign) { template in
                PresetBudgetAssignmentSheet(template: template) {
                    viewModel.loadTemplates(using: viewContext)
                }
                .environment(\.managedObjectContext, viewContext)
                .presentationDetents([.medium, .large])
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
        }
        .background(themeManager.selectedTheme.background.ignoresSafeArea())
    }

    // MARK: - Actions

    /// Deletes selected global templates (and their children).
    /// - Parameter indexSet: indices from the List.
    private func deleteTemplates(_ indexSet: IndexSet) {
        let targets = indexSet.compactMap { idx in viewModel.items[safe: idx]?.template }
        for t in targets {
            PlannedExpenseService.shared.deleteTemplateAndChildren(template: t, in: viewContext)
        }
        saveContext()
        viewModel.loadTemplates(using: viewContext)
    }

    /// Delete a single template via swipe.
    private func delete(template: PlannedExpense) {
        PlannedExpenseService.shared.deleteTemplateAndChildren(template: template, in: viewContext)
        saveContext()
        viewModel.loadTemplates(using: viewContext)
    }

    /// Saves Core Data context.
    private func saveContext() {
        guard viewContext.hasChanges else { return }
        do { try viewContext.save() } catch {
            #if DEBUG
            print("PresetsView save error: \(error)")
            #endif
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
    let actualAmountAggregated: Double
    let assignedCount: Int
    let nextDate: Date?

    // MARK: Formatting Helpers
    var plannedCurrency: String { CurrencyFormatter.shared.string(plannedAmount) }
    var actualCurrency: String { CurrencyFormatter.shared.string(actualAmountAggregated) }
    var nextDateLabel: String {
        guard let d = nextDate else { return "Complete" }
        return DateFormatterCache.shared.mediumDate(d)
    }

    // MARK: Init
    init(template: PlannedExpense,
         plannedAmount: Double,
         actualAmountAggregated: Double,
         assignedCount: Int,
         nextDate: Date?) {
        self.id = template.id ?? UUID()
        self.template = template
        self.name = template.descriptionText ?? "Untitled"
        self.plannedAmount = plannedAmount
        self.actualAmountAggregated = actualAmountAggregated
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
    /// Fetches global templates, aggregates actuals and assignment counts.
    func loadTemplates(using context: NSManagedObjectContext) {
        let templates = PlannedExpenseService.shared.fetchGlobalTemplates(in: context)

        var built: [PresetListItem] = []
        for t in templates {
            let children = PlannedExpenseService.shared.fetchChildren(of: t, in: context)

            let planned = t.plannedAmount
            let actual = children.reduce(0.0) { $0 + $1.actualAmount }
            let assignedCount = children.count

            // Next upcoming date among children; safely unwrap optionals
            let futureDates: [Date] = children
                .compactMap { $0.transactionDate }
                .filter { $0 > Date() }
            let nextDate = futureDates.min()

            built.append(
                PresetListItem(
                    template: t,
                    plannedAmount: planned,
                    actualAmountAggregated: actual,
                    assignedCount: assignedCount,
                    nextDate: nextDate
                )
            )
        }

        // Stable sort by name
        items = built.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
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
        if #available(iOS 16.0, macOS 13.0, *) {
            scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}
