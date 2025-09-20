//
//  AddUnplannedExpenseView.swift
//  SoFar
//
//  Add Variable (Unplanned) Expense
//  -------------------------------------------------------------
//  • Card chooser (horizontal)  ← uses shared CardPickerRow (no local duplicate)
//  • Category chips row (static Add button + live, scrolling chips)
//  • Description, Amount, Date
//  -------------------------------------------------------------?
//

import SwiftUI
import CoreData

// MARK: - AddUnplannedExpenseView
struct AddUnplannedExpenseView: View {

    // MARK: Inputs
    let unplannedExpenseID: NSManagedObjectID?
    let allowedCardIDs: Set<NSManagedObjectID>?
    let initialCardID: NSManagedObjectID?
    let initialDate: Date?
    let onSaved: () -> Void

    // MARK: State
    @StateObject private var vm: AddUnplannedExpenseViewModel
    
    // MARK: - Layout
    /// Height of the card picker row.  This matches the tile height defined in
    /// `CardPickerRow`.  We reduce the height on macOS so the picker doesn’t
    /// overwhelm the form.  Adjust here rather than directly inside
    /// `CardPickerRow` for centralized control.
    #if os(macOS)
    private let cardRowHeight: CGFloat = 150
    #else
    private let cardRowHeight: CGFloat = 160
    #endif


    // MARK: Init
    init(unplannedExpenseID: NSManagedObjectID? = nil,
         allowedCardIDs: Set<NSManagedObjectID>? = nil,
         initialCardID: NSManagedObjectID? = nil,
         initialDate: Date? = nil,
         onSaved: @escaping () -> Void) {
        self.unplannedExpenseID = unplannedExpenseID
        self.allowedCardIDs = allowedCardIDs
        self.initialCardID = initialCardID
        self.initialDate = initialDate
        self.onSaved = onSaved

        let model = AddUnplannedExpenseViewModel(
            unplannedExpenseID: unplannedExpenseID,
            allowedCardIDs: allowedCardIDs,
            initialCardID: initialCardID,
            initialDate: initialDate
        )
        _vm = StateObject<AddUnplannedExpenseViewModel>(wrappedValue: model)
    }

    // MARK: Body
    var body: some View {
        EditSheetScaffold(
            title: vm.isEditing ? "Edit Variable Expense" : "Add Variable Expense",
            saveButtonTitle: vm.isEditing ? "Save Changes" : "Save",
            isSaveEnabled: vm.canSave,
            onSave: { trySave() }
        ) {
            // MARK: Card Picker (horizontal)
            UBFormSection("Assign a Card to Expense", isUppercased: false) {
                CardPickerRow(
                    allCards: vm.allCards,
                    selectedCardID: $vm.selectedCardID
                )
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(height: cardRowHeight)
                .ub_hideScrollIndicators()
            }

            // MARK: Category Chips Row
            UBFormSection("Category", isUppercased: false) {
                CategoryChipsRow(
                    selectedCategoryID: $vm.selectedCategoryID
                )
                .accessibilityElement(children: .contain)
            }


            // MARK: Individual Fields
            // Give each field its own section with a header so that the
            // descriptive label appears outside the cell, mirroring the
            // appearance of the Add Card form.  Also left‑align text for
            // improved readability on macOS and avoid right‑aligned text.

            // Expense Description
            UBFormSection("Expense Description", isUppercased: false) {
                UBFormRow {
                    if #available(iOS 15.0, macOS 12.0, *) {
                        TextField("", text: $vm.descriptionText, prompt: Text("Apple Store"))
                            .ub_noAutoCapsAndCorrection()
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityLabel("Expense Description")
                    } else {
                        TextField("Apple Store", text: $vm.descriptionText)
                            .ub_noAutoCapsAndCorrection()
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityLabel("Expense Description")
                    }
                }
            }

            // Amount
            UBFormSection("Amount", isUppercased: false) {
                UBFormRow {
                    if #available(iOS 15.0, macOS 12.0, *) {
                        TextField("", text: $vm.amountString, prompt: Text("299.99"))
                            .ub_decimalKeyboard()
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityLabel("Amount")
                    } else {
                        TextField("299.99", text: $vm.amountString)
                            .ub_decimalKeyboard()
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityLabel("Amount")
                    }
                }
            }

            // Transaction Date
            UBFormSection("Transaction Date", isUppercased: false) {
                DatePicker("", selection: $vm.transactionDate, displayedComponents: [.date])
                    .labelsHidden()
                    .ub_compactDatePickerStyle()
                    .accessibilityLabel("Transaction Date")
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
            // Resign keyboard on iOS via unified helper
            ub_dismissKeyboard()
            return true
        } catch {
            // Present error via UIKit alert on iOS; macOS simply returns false.
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
            // Hide scroll indicators consistently across platforms
            .ub_hideScrollIndicators()
        }
        .sheet(isPresented: $isPresentingNewCategory) {
            // Present a unified category editor sheet when adding a new category.  The
            // sheet uses the same look and feel as the rest of the app via
            // ExpenseCategoryEditorSheet.  Upon save, it creates a new
            // ExpenseCategory in the current context and passes it back via
            // `onCreated`.
            ExpenseCategoryEditorSheet(
                initialName: "",
                initialHex: "#4E9CFF"
            ) { name, hex in
                // Persist the new category and auto-select it.
                let category = ExpenseCategory(context: viewContext)
                category.id = UUID()
                category.name = name
                category.color = hex
                do {
                    // Obtain a permanent ID so the fetch request updates immediately.
                    try viewContext.obtainPermanentIDs(for: [category])
                    try viewContext.save()
                    // Auto-select the newly created category.
                    selectedCategoryID = category.objectID
                } catch {
                    // In case of an error, log it for debugging; the sheet will stay open.
                    #if DEBUG
                    print("Failed to create category:", error.localizedDescription)
                    #endif
                }
            }
            // Limit the sheet height on iOS/iPadOS to a medium size; macOS uses the default.
            .presentationDetents([.medium])
            .environment(\.managedObjectContext, viewContext)
        }
        .onChange(of: categories.count) { _ in
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
                    Capsule().fill(DS.Colors.chipFill)
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
                .fill(isSelected ? DS.Colors.chipSelectedFill : DS.Colors.chipFill)
        )
        .overlay(
            Capsule()
                .stroke(isSelected ? DS.Colors.chipSelectedStroke : DS.Colors.chipFill, lineWidth: isSelected ? 1.5 : 1)
        )
        .animation(.easeOut(duration: 0.15), value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

