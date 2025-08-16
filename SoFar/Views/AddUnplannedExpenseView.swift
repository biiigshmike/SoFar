//
//  AddUnplannedExpenseView.swift
//  SoFar
//
//  Add Variable (Unplanned) Expense
//  -------------------------------------------------------------
//  • Card chooser (horizontal)  ← uses shared CardPickerRow (no local duplicate)
//  • Category chips row (static Add button + live, scrolling chips)
//  • Description, Amount, Date
//  -------------------------------------------------------------
//

import SwiftUI
import CoreData

// MARK: - AddUnplannedExpenseView
struct AddUnplannedExpenseView: View {

    // MARK: Inputs
    let allowedCardIDs: Set<NSManagedObjectID>?
    let initialDate: Date?
    let onSaved: () -> Void

    // MARK: State
    @StateObject private var vm: AddUnplannedExpenseViewModel

    // MARK: Init
    init(allowedCardIDs: Set<NSManagedObjectID>? = nil,
         initialDate: Date? = nil,
         onSaved: @escaping () -> Void) {
        self.allowedCardIDs = allowedCardIDs
        self.initialDate = initialDate
        self.onSaved = onSaved

        let model = AddUnplannedExpenseViewModel(
            allowedCardIDs: allowedCardIDs,
            initialDate: initialDate
        )
        _vm = StateObject<AddUnplannedExpenseViewModel>(wrappedValue: model)
    }

    // MARK: Body
    var body: some View {
        EditSheetScaffold(
            title: "Add Variable Expense",
            isSaveEnabled: vm.canSave,
            onSave: { trySave() }
        ) {
            // MARK: Card Picker (horizontal)
            Section {
                CardPickerRow(
                    allCards: vm.allCards,
                    selectedCardID: $vm.selectedCardID
                )
            } header: {
                Text("Assign a Card to Expense")
            }

            // MARK: Category Chips Row
            Section {
                CategoryChipsRow(
                    selectedCategoryID: $vm.selectedCategoryID
                )
                .accessibilityElement(children: .contain)
            } header: {
                Text("Category")
            }

            // MARK: Fields
            Section {
                TextField("Expense Description", text: $vm.descriptionText)
                    .ub_noAutoCapsAndCorrection()

                TextField("Amount", text: $vm.amountString)
                    .ub_decimalKeyboard()

                DatePicker("Transaction Date", selection: $vm.transactionDate, displayedComponents: [.date])
                    .ub_compactDatePickerStyle()
            }
        }
        .onAppear { CoreDataService.shared.ensureLoaded() }
        .task { await vm.load() }
        // Make sure our chips & sheet share the same context.
        .environment(\.managedObjectContext, CoreDataService.shared.viewContext)
    }

    // MARK: - trySave()
    /// Validates and persists the expense via the view model.
    /// - Returns: `true` if the sheet should dismiss; `false` to stay open.
    private func trySave() -> Bool {
        guard vm.canSave else { return false }
        do {
            try vm.save()
            onSaved()
            #if canImport(UIKit)
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            #endif
            return true
        } catch {
            #if canImport(UIKit)
            let alert = UIAlertController(title: "Couldn’t Save", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            UIApplication.shared.connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.keyWindow }
                .first?
                .rootViewController?
                .present(alert, animated: true)
            #endif
            return false
        }
    }
}

// MARK: - CategoryChipsRow
/// Shows a static “Add” pill followed by a horizontally-scrolling list of
/// category chips (live via @FetchRequest). Selecting a chip updates the binding.
private struct CategoryChipsRow: View {

    // MARK: Binding
    @Binding var selectedCategoryID: NSManagedObjectID?

    // MARK: Environment
    @Environment(\.managedObjectContext) private var viewContext

    // MARK: Live Fetch
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(key: "name", ascending: true,
                                           selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))]
    )
    private var categories: FetchedResults<ExpenseCategory>

    // MARK: Local State
    @State private var isPresentingNewCategory = false

    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            // MARK: Static Add Button (doesn't scroll)
            AddCategoryPill {
                isPresentingNewCategory = true
            }

            // MARK: Scrolling Chips
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: DS.Spacing.s) {
                    if categories.isEmpty {
                        Text("No categories yet")
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 10)
                    } else {
                        ForEach(categories, id: \.objectID) { cat in
                            CategoryChip(
                                name: cat.name ?? "Untitled",
                                colorHex: cat.color ?? "#999999",
                                isSelected: selectedCategoryID == cat.objectID
                            )
                            .onTapGesture {
                                selectedCategoryID = cat.objectID
                            }
                        }
                    }
                }
                .padding(.trailing, DS.Spacing.s)
            }
        }
        .sheet(isPresented: $isPresentingNewCategory) {
            NewCategorySheet { created in
                // Auto-select the new category when saved
                selectedCategoryID = created.objectID
            }
            .presentationDetents([.medium])
            .environment(\.managedObjectContext, viewContext)
        }
        .onChange(of: categories.count) { _, _ in
            // Auto-pick first category if none selected yet
            if selectedCategoryID == nil, let first = categories.first {
                selectedCategoryID = first.objectID
            }
        }
    }
}

// MARK: - AddCategoryPill
/// Compact, fixed “Add” control styled like a pill.
private struct AddCategoryPill: View {
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Label("Add", systemImage: "plus")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, DS.Spacing.m)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(Color.primary.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add Category")
    }
}

// MARK: - CategoryChip
/// A single pill-shaped category with a color dot and name.
private struct CategoryChip: View {
    let name: String
    let colorHex: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: DS.Spacing.s) {
            Circle()
                .fill(Color(hex: colorHex) ?? .secondary)
                .frame(width: 10, height: 10)
            Text(name)
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, DS.Spacing.m)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(isSelected ? Color.primary.opacity(0.12) : Color.primary.opacity(0.06))
        )
        .overlay(
            Capsule()
                .stroke(isSelected ? Color.primary.opacity(0.35) : Color.primary.opacity(0.12), lineWidth: isSelected ? 1.5 : 1)
        )
        .animation(.easeOut(duration: 0.15), value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - NewCategorySheet
/// Creates a category (name + color) in the SAME environment viewContext.
private struct NewCategorySheet: View {

    // MARK: Callback
    var onCreated: (ExpenseCategory) -> Void

    // MARK: Environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    // MARK: State
    @State private var categoryName: String = ""
    @State private var categoryColor: Color = .blue
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Category name", text: $categoryName)
                        .ub_noAutoCapsAndCorrection()
                } header: { Text("Name") }

                Section {
                    ColorPicker("Color", selection: $categoryColor, supportsOpacity: false)
                } header: { Text("Appearance") }
            }
            .navigationTitle("New Category")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { createCategory() }
                        .disabled(categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
                Button("OK") { errorMessage = nil }
            }, message: { Text(errorMessage ?? "") })
        }
    }

    // MARK: createCategory()
    /// Creates + saves, obtains permanent ID, returns created object.
    private func createCategory() {
        let trimmed = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Please enter a category name."
            return
        }

        do {
            let category = ExpenseCategory(context: viewContext)
            category.id = UUID()
            category.name = trimmed
            category.color = colorToHex(categoryColor) ?? "#999999"

            // Ensure stable ID so selection works immediately.
            try viewContext.obtainPermanentIDs(for: [category])
            try viewContext.save()

            onCreated(category)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: colorToHex(_:)
    /// Converts SwiftUI Color -> "#RRGGBB" (no alpha).
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
