//
//  ExpenseCategoryManagerView.swift
//  SoFar
//
//  Created by Michael Brown on 8/14/25.
//

import SwiftUI
import CoreData

// Conditionally import platform-specific frameworks for color conversions.
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

// MARK: - ExpenseCategoryManagerView
/// Full-fidelity management screen for Expense Categories.
/// - Shows categories, allows add/rename/delete, and color editing.
/// - Uses Core Data directly; integrates with your existing `ExpenseCategory` entity.
/// - Feel free to swap in your `ExpenseCategoryService` later; the UI is decoupled via view model methods.
struct ExpenseCategoryManagerView: View {

    // MARK: Dependencies
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var themeManager: ThemeManager

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
                        .listRowBackground(themeManager.selectedTheme.secondaryBackground)
                } else {
                    ForEach(categories, id: \.objectID) { category in
                        categoryRow(for: category)
                            .listRowBackground(themeManager.selectedTheme.secondaryBackground)
                    }
                    .onDelete(perform: deleteCategories)
                }
            } header: {
                Text("Categories")
            } footer: {
                Text("These categories appear when adding unplanned expenses. Colors help visually group spending.")
            }
            .listRowBackground(themeManager.selectedTheme.secondaryBackground)
        }
        #if os(macOS)
        .listStyle(.inset)
        #else
        .listStyle(.insetGrouped)
        #endif
        .applyIfAvailableScrollContentBackgroundHidden()
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
        .background(themeManager.selectedTheme.background.ignoresSafeArea())
        .accentColor(themeManager.selectedTheme.accent)
        .tint(themeManager.selectedTheme.accent)
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

// MARK: - ExpenseCategoryEditorSheet
/// Modal sheet for adding or editing a category.
/// This sheet adopts the same styling as the other add/edit forms in the app.  It
/// presents two grouped sections—one for the name and one for the color—using
/// `UBFormSection` for consistent header styling.  The `ColorPicker` is used
/// instead of a static hex field so users can tap the color swatch to pick a
/// color on both macOS and iOS.  The `onSave` closure receives the trimmed
/// name and a hex string (e.g., "#4E9CFF") generated from the selected color.
struct ExpenseCategoryEditorSheet: View {
    // MARK: Environment
    @Environment(\.dismiss) private var dismiss

    // MARK: State
    /// Holds the editable name for the category.  The Save button is disabled
    /// until this value is non-empty after trimming whitespace.
    @State private var name: String
    /// Holds the currently selected color.  The initial value is derived from
    /// the provided hex string or falls back to a system blue.
    @State private var color: Color

    // MARK: Callback
    /// Called when the user taps Save.  The closure is passed the trimmed
    /// name and a sanitized hex string representing the current color.
    let onSave: (_ name: String, _ hex: String) -> Void

    // MARK: Init
    init(initialName: String, initialHex: String, onSave: @escaping (_ name: String, _ hex: String) -> Void) {
        self._name = State(initialValue: initialName)
        // Convert the incoming hex string to a Color; default to blue if invalid.
        self._color = State(initialValue: Color(hex: initialHex) ?? .blue)
        self.onSave = onSave
    }

    // MARK: Body
    var body: some View {
        EditSheetScaffold(
            title: "New Category",
            saveButtonTitle: "Save",
            cancelButtonTitle: "Cancel",
            isSaveEnabled: !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            onCancel: nil,
            onSave: {
                // Trim and validate the name; convert the color to a hex string.
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, let hex = colorToHex(color) else { return false }
                onSave(trimmed, hex)
                return true
            }
        ) {
            // Name field
            UBFormSection("Name") {
                // Use an empty label to align the field correctly in the form row.
                TextField("", text: $name, prompt: Text("e.g., Groceries"))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .ub_noAutoCapsAndCorrection()
            }

            // Color picker
            UBFormSection("Color") {
                ColorPicker("Color", selection: $color, supportsOpacity: false)
                    // Hide the inline label so the control fills the row.
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        // Apply our consistent form styling.
        .ub_formStyleGrouped()
        .ub_hideScrollIndicators()
    }

    // MARK: Helper: Color -> Hex
    /// Converts a SwiftUI `Color` into a `#RRGGBB` uppercase hex string.  Returns
    /// nil if conversion fails (e.g., color isn't representable in sRGB).
    private func colorToHex(_ color: Color) -> String? {
        #if canImport(UIKit)
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        let ri = Int(round(r * 255)), gi = Int(round(g * 255)), bi = Int(round(b * 255))
        return String(format: "#%02X%02X%02X", ri, gi, bi)
        #elseif canImport(AppKit)
        if #available(macOS 11.0, *) {
            guard let sRGB = NSColor(color).usingColorSpace(.sRGB) else { return nil }
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            sRGB.getRed(&r, green: &g, blue: &b, alpha: &a)
            let ri = Int(round(r * 255)), gi = Int(round(g * 255)), bi = Int(round(b * 255))
            return String(format: "#%02X%02X%02X", ri, gi, bi)
        } else {
            return nil
        }
        #endif
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
