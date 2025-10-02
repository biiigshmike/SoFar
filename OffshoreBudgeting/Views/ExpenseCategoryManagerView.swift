//
//  ExpenseCategoryManagerView.swift
//  SoFar
//
//  Created by Michael Brown on 8/14/25.
//

import SwiftUI
import CoreData
import UIKit

// MARK: - ExpenseCategoryManagerView
struct ExpenseCategoryManagerView: View {

    // MARK: Dependencies
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.isOnboardingPresentation) private var isOnboardingPresentation

    // MARK: Sorting
    private static let sortByName: [NSSortDescriptor] = [
        NSSortDescriptor(key: "name", ascending: true)
    ]

    // MARK: Fetch Request
    @FetchRequest(
        sortDescriptors: ExpenseCategoryManagerView.sortByName,
        animation: .default
    )
    private var categories: FetchedResults<ExpenseCategory>

    // MARK: UI State
    @State private var isPresentingAddSheet: Bool = false
    @State private var categoryToEdit: ExpenseCategory?
    @State private var categoryToDelete: ExpenseCategory?
    @AppStorage(AppSettingsKeys.confirmBeforeDelete.rawValue) private var confirmBeforeDelete: Bool = true

    // MARK: Body
    var body: some View {
        Group {
            if isOnboardingPresentation {
                baseView
            } else {
                baseView
                    .ub_surfaceBackground(
                        themeManager.selectedTheme,
                        configuration: themeManager.glassConfiguration,
                        ignoringSafeArea: .all
                    )
            }
        }
        .accentColor(themeManager.selectedTheme.resolvedTint)
        .tint(themeManager.selectedTheme.resolvedTint)
        .sheet(isPresented: $isPresentingAddSheet) {
            ExpenseCategoryEditorSheet(
                initialName: "",
                initialHex: "#4E9CFF",
                onSave: { name, hex in addCategory(name: name, hex: hex) }
            )
        }
        .sheet(item: $categoryToEdit) { category in
            ExpenseCategoryEditorSheet(
                initialName: category.name ?? "",
                initialHex: category.color ?? "#999999",
                onSave: { name, hex in
                    category.name = name
                    category.color = hex
                    saveContext()
                }
            )
        }
        .alert(item: $categoryToDelete) { cat in
            let counts = usageCounts(for: cat)
            let title = Text(#"Delete \#(cat.name ?? "Category")?"#)
            let message: Text = {
                if counts.total > 0 {
                    return Text(#"This category is used by \#(counts.planned) planned and \#(counts.unplanned) variable expenses. Deleting it will also delete those expenses."#)
                } else {
                    return Text("This will remove the category.")
                }
            }()
            return Alert(
                title: title,
                message: message,
                primaryButton: .destructive(Text(counts.total > 0 ? "Delete Category & Expenses" : "Delete")) { deleteCategory(cat) },
                secondaryButton: .cancel()
            )
        }
    }

    private var baseView: some View {
        Group {
            if categories.isEmpty {
                emptyState
            } else {
                List {
                    Section {
                        ForEach(categories, id: \.objectID) { category in
                            categoryRow(for: category)
                                .listRowBackground(themeManager.selectedTheme.secondaryBackground)
                        }
                        .onDelete { offsets in
                            let targets = offsets.map { categories[$0] }
                            if let used = targets.first(where: { usageCounts(for: $0).total > 0 }) {
                                categoryToDelete = used
                            } else if confirmBeforeDelete, let first = targets.first {
                                categoryToDelete = first
                            } else {
                                targets.forEach(deleteCategory(_:))
                            }
                        }
                    } header: {
                        Text("Categories")
                    } footer: {
                        Text("These categories appear when adding expenses. Colors help visually group spending.")
                    }
                    .listRowBackground(themeManager.selectedTheme.secondaryBackground)
                }
                .listStyle(.insetGrouped)
                .applyIfAvailableScrollContentBackgroundHidden()
            }
        }
        .navigationTitle("Manage Categories")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { isPresentingAddSheet = true } label: { Label("Add Category", systemImage: "plus") }
            }
        }
    }

    // MARK: - Row Builders
    @ViewBuilder
    private func categoryRow(for category: ExpenseCategory) -> some View {
        Button { categoryToEdit = category } label: { rowLabel(for: category) }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
    }

    @ViewBuilder
    private func rowLabel(for category: ExpenseCategory) -> some View {
        HStack(spacing: 12) {
            ColorCircle(hex: category.color ?? "#999999")
            VStack(alignment: .leading) {
                Text(category.name ?? "Untitled")
                Text(category.color ?? "#999999")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        UBEmptyState(
            iconSystemName: "tag",
            title: "Categories",
            message: "Create categories to track your spending. You can always edit them later.",
            primaryButtonTitle: "Add Category",
            onPrimaryTap: { isPresentingAddSheet = true }
        )
        .padding(.horizontal, DS.Spacing.l)
    }

    // MARK: - CRUD
    private func addCategory(name: String, hex: String) {
        let new = ExpenseCategory(context: viewContext)
        new.id = UUID()
        new.name = name
        new.color = hex
        saveContext()
    }

    private func deleteCategory(_ cat: ExpenseCategory) {
        // Fetch and delete all expenses referencing this category (planned and variable).
        let reqP = NSFetchRequest<PlannedExpense>(entityName: "PlannedExpense")
        reqP.predicate = NSPredicate(format: "expenseCategory == %@", cat)
        let planned = (try? viewContext.fetch(reqP)) ?? []

        let reqU = NSFetchRequest<UnplannedExpense>(entityName: "UnplannedExpense")
        reqU.predicate = NSPredicate(format: "expenseCategory == %@", cat)
        let unplanned = (try? viewContext.fetch(reqU)) ?? []

        planned.forEach { viewContext.delete($0) }
        unplanned.forEach { viewContext.delete($0) }
        viewContext.delete(cat)
        saveContext()
    }

    // MARK: Usage counting (excludes global templates to match user-visible "in use")
    private func usageCounts(for category: ExpenseCategory) -> (planned: Int, unplanned: Int, total: Int) {
        // Planned: exclude isGlobal == true (templates)
        let reqP = NSFetchRequest<NSNumber>(entityName: "PlannedExpense")
        reqP.resultType = .countResultType
        reqP.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "expenseCategory == %@", category),
            NSPredicate(format: "isGlobal == NO")
        ])
        let plannedCount = (try? viewContext.count(for: reqP)) ?? 0

        // Unplanned: count all
        let reqU = NSFetchRequest<NSNumber>(entityName: "UnplannedExpense")
        reqU.resultType = .countResultType
        reqU.predicate = NSPredicate(format: "expenseCategory == %@", category)
        let unplannedCount = (try? viewContext.count(for: reqU)) ?? 0

        return (plannedCount, unplannedCount, plannedCount + unplannedCount)
    }

    private func saveContext() {
        do { try viewContext.save() }
        catch { AppLog.ui.error("Failed to save categories: \(error.localizedDescription)") }
    }
}

// MARK: - Availability Helpers
private extension View {
    @ViewBuilder
    func applyIfAvailableScrollContentBackgroundHidden() -> some View {
        if #available(iOS 16.0, macCatalyst 16.0, *) {
            scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}

// MARK: - ExpenseCategoryEditorSheet
struct ExpenseCategoryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var color: Color

    let onSave: (_ name: String, _ hex: String) -> Void

    init(initialName: String, initialHex: String, onSave: @escaping (_ name: String, _ hex: String) -> Void) {
        self._name = State(initialValue: initialName)
        self._color = State(initialValue: Color(hex: initialHex) ?? .blue)
        self.onSave = onSave
    }

    var body: some View {
        EditSheetScaffold(
            title: "New Category",
            saveButtonTitle: "Save",
            cancelButtonTitle: "Cancel",
            isSaveEnabled: !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            onCancel: nil,
            onSave: {
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, let hex = colorToHex(color) else { return false }
                onSave(trimmed, hex)
                return true
            }
        ) {
            UBFormSection("Name") {
                UBFormRow {
                    TextField("", text: $name, prompt: Text("Shopping"))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                }
            }

            UBFormSection("Color") {
                ColorPicker("Color", selection: $color, supportsOpacity: false)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .ub_formStyleGrouped()
        .ub_hideScrollIndicators()
    }

    private func colorToHex(_ color: Color) -> String? {
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        let ri = Int(round(r * 255)), gi = Int(round(g * 255)), bi = Int(round(b * 255))
        return String(format: "#%02X%02X%02X", ri, gi, bi)
    }
}

// MARK: - ColorCircle
struct ColorCircle: View {
    var hex: String

    var body: some View {
        Circle()
            .fill(colorFromHex(hex) ?? .gray.opacity(0.4))
            .frame(width: 24, height: 24)
            .overlay(
                Circle().strokeBorder(Color.primary.opacity(0.1))
            )
            .accessibilityHidden(true)
    }

    private func colorFromHex(_ hex: String) -> Color? {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let intVal = Int(value, radix: 16) else { return nil }
        let r = Double((intVal >> 16) & 0xFF) / 255.0
        let g = Double((intVal >> 8) & 0xFF) / 255.0
        let b = Double(intVal & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }
}
