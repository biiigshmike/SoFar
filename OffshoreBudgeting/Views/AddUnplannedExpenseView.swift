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
import UIKit
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
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var isPresentingAddCard = false
    
    // MARK: - Layout
    /// Height of the card picker row.  This matches the tile height defined in
    /// `CardPickerRow` so adjustments remain centralized.
    private let cardRowHeight: CGFloat = 160


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
                if vm.allCards.isEmpty {
                    VStack(spacing: DS.Spacing.m) {
                        Text("No cards yet. Add one to assign this expense.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        GlassCTAButton(
                            maxWidth: .infinity,
                            fillHorizontally: true,
                            fallbackAppearance: .neutral,
                            action: { isPresentingAddCard = true }
                        ) {
                            Label("Add Card", systemImage: "plus")
                        }
                        .accessibilityLabel("Add Card")
                    }
                } else {
                    CardPickerRow(
                        allCards: vm.allCards,
                        selectedCardID: $vm.selectedCardID
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: cardRowHeight)
                    .ub_hideScrollIndicators()
                }
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
                    if #available(iOS 15.0, macCatalyst 15.0, *) {
                        TextField("", text: $vm.descriptionText, prompt: Text("Apple Store"))
                            .autocorrectionDisabled(true)
                            .textInputAutocapitalization(.never)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityLabel("Expense Description")
                    } else {
                        TextField("Apple Store", text: $vm.descriptionText)
                            .autocorrectionDisabled(true)
                            .textInputAutocapitalization(.never)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityLabel("Expense Description")
                    }
                }
            }

            // Amount
            UBFormSection("Amount", isUppercased: false) {
                UBFormRow {
                    if #available(iOS 15.0, macCatalyst 15.0, *) {
                        TextField("", text: $vm.amountString, prompt: Text("299.99"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityLabel("Amount")
                    } else {
                        TextField("299.99", text: $vm.amountString)
                            .keyboardType(.decimalPad)
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
        .sheet(isPresented: $isPresentingAddCard) {
            AddCardFormView { newName, selectedTheme in
                do {
                    let service = CardService()
                    let card = try service.createCard(name: newName)
                    if let uuid = card.value(forKey: "id") as? UUID {
                        CardAppearanceStore.shared.setTheme(selectedTheme, for: uuid)
                    }
                    vm.selectedCardID = card.objectID
                } catch {
                    let alert = UIAlertController(title: "Couldn’t Create Card", message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    UIApplication.shared.connectedScenes
                        .compactMap { ($0 as? UIWindowScene)?.keyWindow }
                        .first?
                        .rootViewController?
                        .present(alert, animated: true)
                }
            }
        }
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
            let alert = UIAlertController(title: "Couldn’t Save", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            UIApplication.shared.connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.keyWindow }
                .first?
                .rootViewController?
                .present(alert, animated: true)
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
    @Environment(\.platformCapabilities) private var capabilities
    @EnvironmentObject private var themeManager: ThemeManager
    @Namespace private var glassNamespace

    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            // MARK: Static Add Button (doesn't scroll)
            AddCategoryPill {
                isPresentingNewCategory = true
            }

            // MARK: Scrolling Chips (wrapped in a single GlassEffectContainer on OS26)
            Group {
                if capabilities.supportsOS26Translucency, #available(iOS 26.0, macCatalyst 26.0, *) {
                    GlassEffectContainer(spacing: DS.Spacing.s) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: DS.Spacing.s) {
                                if categories.isEmpty {
                                    Text("No categories yet")
                                        .foregroundStyle(.secondary)
                                        .padding(.vertical, 10)
                                } else {
                                    ForEach(categories, id: \.objectID) { cat in
                                        let isSel = selectedCategoryID == cat.objectID
                                        CategoryChip(
                                            id: cat.objectID.uriRepresentation().absoluteString,
                                            name: cat.name ?? "Untitled",
                                            colorHex: cat.color ?? "#999999",
                                            isSelected: isSel,
                                            namespace: glassNamespace
                                        )
                                        .onTapGesture { selectedCategoryID = cat.objectID }
                                        .glassEffectTransition(.matchedGeometry)
                                    }
                                }
                            }
                            .padding(.horizontal, DS.Spacing.s)
                        }
                    }
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: DS.Spacing.s) {
                            if categories.isEmpty {
                                Text("No categories yet")
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 10)
                            } else {
                                ForEach(categories, id: \.objectID) { cat in
                                    CategoryChip(
                                        id: cat.objectID.uriRepresentation().absoluteString,
                                        name: cat.name ?? "Untitled",
                                        colorHex: cat.color ?? "#999999",
                                        isSelected: selectedCategoryID == cat.objectID,
                                        namespace: nil
                                    )
                                    .onTapGesture { selectedCategoryID = cat.objectID }
                                }
                            }
                        }
                        .padding(.horizontal, DS.Spacing.s)
                    }
                }
            }
            // Hide scroll indicators consistently across platforms
            .ub_hideScrollIndicators()
        }
        .sheet(isPresented: $isPresentingNewCategory) {
            // Build as a single expression to avoid opaque 'some View' type mismatches.
            let base = ExpenseCategoryEditorSheet(
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
                    AppLog.ui.error("Failed to create category: \(error.localizedDescription)")
                }
            }
            .environment(\.managedObjectContext, viewContext)

            // Apply detents on supported OS versions without changing the opaque type.
            Group {
                if #available(iOS 16.0, *) {
                    base.presentationDetents([.medium])
                } else {
                    base
                }
            }
        }
        .ub_onChange(of: categories.count) {
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
    @Environment(\.platformCapabilities) private var capabilities
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        Button(action: onTap) {
            Label("Add", systemImage: "plus")
                .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(
            AddCategoryPillStyle(
                tint: themeManager.selectedTheme.resolvedTint
            )
        )
        .controlSize(.regular)
        .accessibilityLabel("Add Category")
    }
}

// MARK: - CategoryChip
/// A single pill-shaped category with a color dot and name.
private struct CategoryChip: View {
    let id: String
    let name: String
    let colorHex: String
    let isSelected: Bool
    let namespace: Namespace.ID?
    @Environment(\.platformCapabilities) private var capabilities
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let categoryColor = Color(hex: colorHex) ?? .secondary
        let style = CategoryChipStyle.make(
            isSelected: isSelected,
            categoryColor: categoryColor,
            colorScheme: colorScheme
        )

        let shouldApplyShadow = style.shadowRadius > 0 || style.shadowY != 0

        func convertStroke(_ stroke: CategoryChipStyle.Stroke?) -> CategoryChipPill<EmptyView>.Stroke? {
            guard let stroke, stroke.lineWidth > 0 else { return nil }
            return .init(color: stroke.color, lineWidth: stroke.lineWidth)
        }

        let glassStroke = convertStroke(style.glassStroke)
        let fallbackStroke = convertStroke(style.fallbackStroke)

        var chip = CategoryChipPill(
            isSelected: isSelected,
            selectionColor: categoryColor,
            glassStroke: glassStroke,
            fallbackFill: style.fallbackFill,
            fallbackStroke: fallbackStroke
        ) {
            HStack(spacing: DS.Spacing.s) {
                Circle()
                    .fill(categoryColor)
                    .frame(width: 10, height: 10)
                Text(name)
                    .font(.subheadline.weight(.semibold))
            }
        }

        if capabilities.supportsOS26Translucency, #available(iOS 26.0, macCatalyst 26.0, *) {
            chip = chip
                .foregroundStyle(style.glassTextColor)
                .glassEffectTransition(.matchedGeometry)

            if let ns = namespace {
                chip = chip.glassEffectID(id, in: ns)
            }
        } else {
            chip = chip.foregroundStyle(style.fallbackTextColor)
        }

        let base = chip
            .scaleEffect(style.scale)
            .animation(.easeOut(duration: 0.15), value: isSelected)
            .accessibilityAddTraits(isSelected ? .isSelected : [])

        if shouldApplyShadow {
            base
                .shadow(
                    color: style.shadowColor,
                    radius: style.shadowRadius,
                    x: 0,
                    y: style.shadowY
                )
        } else {
            base
        }
    }

}

// MARK: - Styles
private struct AddCategoryPillStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        let isActive = configuration.isPressed
        let pill = CategoryChipPill(
            isSelected: false,
            selectionColor: nil
        ) {
            configuration.label
        }

        return pill
            .foregroundStyle(.primary)
            .overlay {
                if isActive {
                    Capsule(style: .continuous)
                        .strokeBorder(tint.opacity(0.35), lineWidth: 1.5)
                }
            }
            .animation(.easeOut(duration: 0.15), value: isActive)
    }
}
