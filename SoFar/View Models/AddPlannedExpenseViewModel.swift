//
//  AddPlannedExpenseViewModel.swift
//  SoFar
//
//  Handles adding a PlannedExpense to a selected Budget.
//  Can optionally mark the expense as a global preset (isGlobal == true)
//  so it appears in “Presets” for quick-add later.
//

import Foundation
import CoreData

// MARK: - AddPlannedExpenseViewModel
@MainActor
final class AddPlannedExpenseViewModel: ObservableObject {

    // MARK: Dependencies
    private let context: NSManagedObjectContext

    // MARK: Identity
    private let plannedExpenseID: NSManagedObjectID?
    let isEditing: Bool
    /// When false, a budget is optional (used for preset-only creation).
    private let requiresBudgetSelection: Bool

    // MARK: Loaded Data
    @Published private(set) var allBudgets: [Budget] = []

    // MARK: Form State
    @Published var selectedBudgetID: NSManagedObjectID?
    @Published var descriptionText: String = ""
    @Published var plannedAmountString: String = ""
    @Published var actualAmountString: String = ""
    @Published var transactionDate: Date = Date()
    @Published var saveAsGlobalPreset: Bool = false

    /// Tracks whether the item being edited was originally a global template.
    private var editingOriginalIsGlobal: Bool = false

    // MARK: Init
    init(plannedExpenseID: NSManagedObjectID? = nil,
         preselectedBudgetID: NSManagedObjectID? = nil,
         requiresBudgetSelection: Bool = true,
         initialDate: Date? = nil,
         context: NSManagedObjectContext = CoreDataService.shared.viewContext) {
        self.context = context
        self.plannedExpenseID = plannedExpenseID
        self.isEditing = plannedExpenseID != nil
        self.requiresBudgetSelection = requiresBudgetSelection
        self.selectedBudgetID = preselectedBudgetID
        if let d = initialDate { self.transactionDate = d }
    }

    // MARK: load()
    func load() async {
        CoreDataService.shared.ensureLoaded()
        allBudgets = fetchBudgets()

        if isEditing, let id = plannedExpenseID,
           let existing = try? context.existingObject(with: id) as? PlannedExpense {
            selectedBudgetID = existing.budget?.objectID
            descriptionText = existing.descriptionText ?? ""
            plannedAmountString = formatAmount(existing.plannedAmount)
            actualAmountString = formatAmount(existing.actualAmount)
            transactionDate = existing.transactionDate ?? Date()
            saveAsGlobalPreset = existing.isGlobal
            editingOriginalIsGlobal = existing.isGlobal
        } else {
            // If preselected not provided, default to most-recent budget by start date.
            // For preset creation where a budget is optional, we intentionally
            // leave `selectedBudgetID` nil until the user opts to assign one.
            if requiresBudgetSelection && selectedBudgetID == nil {
                selectedBudgetID = allBudgets.first?.objectID
            }
        }
    }

    // MARK: Validation
    var canSave: Bool {
        let amountValid = Double(plannedAmountString.replacingOccurrences(of: ",", with: "")) != nil
        let textValid = !descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if isEditing && editingOriginalIsGlobal {
            // Editing a parent template does not require selecting a budget.
            return textValid && amountValid
        }
        if !requiresBudgetSelection && saveAsGlobalPreset {
            // Adding a new global preset without attaching to a budget.
            return textValid && amountValid
        }
        return selectedBudgetID != nil && textValid && amountValid
    }

    // MARK: save()
    func save() throws {
        let plannedAmt = Double(plannedAmountString.replacingOccurrences(of: ",", with: "")) ?? 0
        let actualAmt  = Double(actualAmountString.replacingOccurrences(of: ",", with: "")) ?? 0

        if isEditing,
           let id = plannedExpenseID,
           let existing = try? context.existingObject(with: id) as? PlannedExpense {
            existing.descriptionText = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.plannedAmount = plannedAmt
            existing.actualAmount = actualAmt
            existing.transactionDate = transactionDate
            if editingOriginalIsGlobal {
                // Editing a parent template; keep it global and unattached.
                existing.isGlobal = true
                existing.budget = nil
            } else {
                guard let budgetID = selectedBudgetID,
                      let targetBudget = context.object(with: budgetID) as? Budget else {
                    throw NSError(domain: "SoFar.AddPlannedExpense", code: 10, userInfo: [NSLocalizedDescriptionKey: "Please select a budget."])
                }
                existing.isGlobal = false
                existing.budget = targetBudget
            }
        } else {
            let trimmed = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)

            if saveAsGlobalPreset {
                // Create a global parent template
                let parent = PlannedExpense(context: context)
                parent.id = parent.id ?? UUID()
                parent.descriptionText = trimmed
                parent.plannedAmount = plannedAmt
                parent.actualAmount = 0
                parent.transactionDate = transactionDate
                parent.isGlobal = true
                parent.budget = nil

                if let budgetID = selectedBudgetID,
                   let targetBudget = context.object(with: budgetID) as? Budget {
                    // Optionally create a child attached to a budget if one was selected
                    let child = PlannedExpense(context: context)
                    child.id = child.id ?? UUID()
                    child.descriptionText = trimmed
                    child.plannedAmount = plannedAmt
                    child.actualAmount = actualAmt
                    child.transactionDate = transactionDate
                    child.isGlobal = false
                    child.globalTemplateID = parent.id
                    child.budget = targetBudget
                }
            } else {
                guard let budgetID = selectedBudgetID,
                      let targetBudget = context.object(with: budgetID) as? Budget else {
                    throw NSError(domain: "SoFar.AddPlannedExpense", code: 10, userInfo: [NSLocalizedDescriptionKey: "Please select a budget."])
                }

                // Standard single planned expense
                let item = PlannedExpense(context: context)
                item.id = item.id ?? UUID()
                item.descriptionText = trimmed
                item.plannedAmount = plannedAmt
                item.actualAmount = actualAmt
                item.transactionDate = transactionDate
                item.isGlobal = false
                item.budget = targetBudget
            }
        }

        try context.save()
    }

    // MARK: Private fetch
    private func fetchBudgets() -> [Budget] {
        let req = NSFetchRequest<Budget>(entityName: "Budget")
        req.sortDescriptors = [
            NSSortDescriptor(key: "startDate", ascending: false),
            NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
        ]
        return (try? context.fetch(req)) ?? []
    }

    private func formatAmount(_ value: Double) -> String {
        let nf = NumberFormatter()
        nf.locale = .current
        nf.numberStyle = .decimal
        nf.minimumFractionDigits = 0
        nf.maximumFractionDigits = 2
        return nf.string(from: NSNumber(value: value)) ?? ""
    }
}
