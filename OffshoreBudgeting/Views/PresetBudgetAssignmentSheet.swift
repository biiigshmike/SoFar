//
//  PresetBudgetAssignmentSheet.swift
//  SoFar
//
//  Created by Michael Brown on 8/14/25.
//

import SwiftUI
import CoreData

// MARK: - PresetBudgetAssignmentSheet
/// Sheet that lists all budgets with a toggle to assign/unassign the given
/// global template. Assigning creates a child PlannedExpense linked to the
/// selected budget; unassigning deletes that child.
struct PresetBudgetAssignmentSheet: View {

    // MARK: Environment
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager

    // MARK: Inputs
    let template: PlannedExpense
    var onChangesCommitted: (() -> Void)?

    // MARK: State
    @State private var budgets: [Budget] = []
    @State private var membership: [UUID: Bool] = [:] // Budget.id : isAssigned

    // MARK: Body
    var body: some View {
        navigationContainer {
            List {
                ForEach(budgets, id: \.self) { budget in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(budget.name ?? "Untitled Budget")
                                .font(.body)
                            if let s = budget.startDate, let e = budget.endDate {
                                Text(dateSpanLabel(start: s, end: e))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Toggle("", isOn: Binding<Bool>(
                            get: { isAssigned(to: budget) },
                            set: { newValue in toggleAssignment(for: budget, to: newValue) }
                        ))
                        .labelsHidden()
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("Assign to Budgets")
            .toolbar {
                // MARK: Toolbar Buttons
                // Cross-platform placements:
                #if os(iOS) || os(visionOS)
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        saveContext()
                        onChangesCommitted?()
                        dismiss()
                    }
                    .font(.headline)
                }
                #else
                // macOS fallback
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveContext()
                        onChangesCommitted?()
                        dismiss()
                    }
                    .font(.headline)
                }
                #endif
            }
            .onAppear { reload() }
        }
        .ub_navigationGlassBackground(
            baseColor: themeManager.selectedTheme.glassBaseColor,
            configuration: themeManager.glassConfiguration
        )
    }

    // MARK: - Navigation container (iOS 16+/macOS 13+ NavigationStack; older NavigationView)
    @ViewBuilder
    private func navigationContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            NavigationStack { content() }
        } else {
            NavigationView { content() }
        }
    }

    // MARK: - Load
    /// Loads budgets and current assignment membership.
    private func reload() {
        budgets = PlannedExpenseService.shared.fetchAllBudgets(in: viewContext)
        let children = PlannedExpenseService.shared.fetchChildren(of: template, in: viewContext)
        let assignedBudgetIDs = Set(children.compactMap { $0.budget?.id })
        membership = [:]
        for b in budgets {
            guard let id = b.id else { continue }
            membership[id] = assignedBudgetIDs.contains(id)
        }
    }

    // MARK: - Membership Utilities
    private func isAssigned(to budget: Budget) -> Bool {
        guard let id = budget.id else { return false }
        return membership[id] ?? false
    }

    private func toggleAssignment(for budget: Budget, to newValue: Bool) {
        guard let budgetID = budget.id else { return }
        if newValue {
            PlannedExpenseService.shared.ensureChild(from: template, attachedTo: budget, in: viewContext)
        } else {
            PlannedExpenseService.shared.removeChild(from: template, for: budget, in: viewContext)
        }
        membership[budgetID] = newValue
    }

    // MARK: - Save
    private func saveContext() {
        guard viewContext.hasChanges else { return }
        do { try viewContext.save() } catch {
            #if DEBUG
            print("PresetBudgetAssignmentSheet save error: \(error)")
            #endif
        }
    }

    // MARK: - Formatting
    private func dateSpanLabel(start: Date, end: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return "\(f.string(from: start)) – \(f.string(from: end))"
    }
}
