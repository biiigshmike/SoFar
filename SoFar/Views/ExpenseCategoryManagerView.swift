//
//  ExpenseCategoryManagerView.swift
//  SoFar
//
//  Created by Michael Brown on 8/14/25.
//

import SwiftUI
import CoreData

// MARK: - ExpenseCategoryManagerView
/// Full-fidelity management screen for Expense Categories.
/// - Shows categories, allows add/rename/delete, and color editing.
/// - Uses Core Data directly; integrates with your existing `ExpenseCategory` entity.
/// - Feel free to swap in your `ExpenseCategoryService` later; the UI is decoupled via view model methods.
struct ExpenseCategoryManagerView: View {

    // MARK: Dependencies
    @Environment(\.managedObjectContext) private var viewContext

    // MARK: Sorting (extracted to avoid heavy type inference)
    /// Keeping sort descriptors as a static constant helps Swift’s type-checker.
    private static let sortByName: [NSSortDescriptor] = [
        NSSortDescriptor(key: "name", ascending: true)
    ]

    // MARK: Fetch Request
    /// Using the simpler `key:` initializer instead of the keyPath one prevents the slow
    /// type-checker behavior on some toolchains.
    @FetchRequest(
        sortDescriptors: ExpenseCategoryManagerView.sortByName,
        animation: .default
    )
    private var categories: FetchedResults<ExpenseCategory>

    // MARK: UI State
    @State private var isPresentingAddSheet: Bool = false
    @State private var categoryToEdit: ExpenseCategory?

    // MARK: - Body
    var body: some View {
        List {
            Section {
                if categories.isEmpty {
                    emptyState
                } else {
                    ForEach(categories, id: \.objectID) { category in
                        categoryRow(for: category)
                    }
                    .onDelete(perform: deleteCategories)
                }
            } header: {
                Text("Categories")
            } footer: {
                Text("These categories appear when adding unplanned expenses. Colors help visually group spending.")
            }
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Manage Categories")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isPresentingAddSheet = true
                } label: {
                    Label("Add Category", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isPresentingAddSheet) {
            ExpenseCategoryEditorSheet(
                initialName: "",
                initialHex: "#4E9CFF",
                onSave: { name, hex in
                    addCategory(name: name, hex: hex)
                }
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
    }

    // MARK: - Row Builders
    /// Builds the tappable row for a single category; extracted to help the compiler.
    /// - Parameter category: The Core Data `ExpenseCategory` object to show.
    /// - Returns: A button that pushes the editor sheet.
    @ViewBuilder
    private func categoryRow(for category: ExpenseCategory) -> some View {
        Button {
            categoryToEdit = category
        } label: {
            rowLabel(for: category)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    /// Pure label view for the row; shows a color chip, name, hex, and chevron.
    /// - Parameter category: The category to display.
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
        VStack(spacing: 12) {
            Image(systemName: "tag")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.orange)

            Text("No Categories Yet")
                .font(.headline)

            Text("Tap Add to create your first category. You can customize its color and name at any time.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - CRUD
    /// Adds a new ExpenseCategory to Core Data.
    /// - Parameters:
    ///   - name: Visible label for the category.
    ///   - hex: Hex string (e.g., "#FFAA00") used to render the color chip.
    private func addCategory(name: String, hex: String) {
        let new = ExpenseCategory(context: viewContext)
        new.id = UUID()
        new.name = name
        new.color = hex
        saveContext()
    }

    /// Deletes selected categories from the fetch request.
    private func deleteCategories(at offsets: IndexSet) {
        for index in offsets {
            let cat = categories[index]
            viewContext.delete(cat)
        }
        saveContext()
    }

    /// Saves context with a lightweight error handler; replace with AlertHelper if desired.
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            #if DEBUG
            print("Failed to save categories:", error.localizedDescription)
            #endif
        }
    }
}

// MARK: - ExpenseCategoryEditorSheet
/// Modal sheet for adding or editing a category.
/// - Parameters:
///   - initialName: Prefills the name field when editing.
///   - initialHex: Prefills the hex string; validate lightly.
///   - onSave: Closure invoked with new values; the caller persists.
struct ExpenseCategoryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var hex: String

    let onSave: (_ name: String, _ hex: String) -> Void

    init(initialName: String, initialHex: String, onSave: @escaping (_ name: String, _ hex: String) -> Void) {
        self._name = State(initialValue: initialName)
        self._hex = State(initialValue: initialHex)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    // Name
                    TextField("Name", text: $name)
                    #if os(iOS)
                        .textInputAutocapitalization(.words)
                    #endif

                    // Hex
                    TextField("#RRGGBB", text: $hex)
                    #if os(iOS)
                        .textInputAutocapitalization(.never)
                    #endif
                        .autocorrectionDisabled(true)

                    HStack {
                        ColorCircle(hex: hex)
                        Text("Preview")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Category")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let sanitized = sanitizeHex(hex)
                        onSave(name.trimmingCharacters(in: .whitespacesAndNewlines), sanitized)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sanitizeHex(hex).isEmpty == true)
                }
            }
        }
        .frame(minWidth: sheetMinWidth)
    }

    // MARK: - Helpers
    private var sheetMinWidth: CGFloat {
        #if os(macOS)
        return 420
        #else
        return 0
        #endif
    }

    /// Sanitizes a hex string; returns uppercase #RRGGBB or empty string if invalid.
    private func sanitizeHex(_ value: String) -> String {
        var v = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if v.hasPrefix("#") == false { v = "#\(v)" }
        let pattern = #"^#[0-9A-F]{6}$"#
        if v.range(of: pattern, options: .regularExpression) != nil {
            return v
        }
        return ""
    }
}

// MARK: - ColorCircle
/// Renders a circular color chip from a hex string; falls back to system gray if invalid.
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

    // MARK: Utility
    /// Converts #RRGGBB to a SwiftUI Color.
    private func colorFromHex(_ hex: String) -> Color? {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6,
              let intVal = Int(value, radix: 16) else { return nil }
        let r = Double((intVal >> 16) & 0xFF) / 255.0
        let g = Double((intVal >> 8) & 0xFF) / 255.0
        let b = Double(intVal & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }
}
