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

    // MARK: Loaded Data
    @Published private(set) var allBudgets: [Budget] = []

    // MARK: Form State
    @Published var selectedBudgetID: NSManagedObjectID?
    @Published var descriptionText: String = ""
    @Published var plannedAmountString: String = ""
    @Published var actualAmountString: String = ""
    @Published var transactionDate: Date = Date()
    @Published var saveAsGlobalPreset: Bool = false

    // MARK: Init
    init(preselectedBudgetID: NSManagedObjectID? = nil,
         initialDate: Date? = nil,
         context: NSManagedObjectContext = CoreDataService.shared.viewContext) {
        self.context = context
        self.selectedBudgetID = preselectedBudgetID
        if let d = initialDate { self.transactionDate = d }
    }

    // MARK: load()
    func load() async {
        CoreDataService.shared.ensureLoaded()
        allBudgets = fetchBudgets()
        // If preselected not provided, default to most-recent budget by start date
        if selectedBudgetID == nil { selectedBudgetID = allBudgets.first?.objectID }
    }

    // MARK: Validation
    var canSave: Bool {
        selectedBudgetID != nil
        && !descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && (Double(plannedAmountString.replacingOccurrences(of: ",", with: "")) != nil)
    }

    // MARK: save()
    func save() throws {
        guard let budgetID = selectedBudgetID,
              let targetBudget = context.object(with: budgetID) as? Budget else {
            throw NSError(domain: "SoFar.AddPlannedExpense", code: 10, userInfo: [NSLocalizedDescriptionKey: "Please select a budget."])
        }

        let plannedAmt = Double(plannedAmountString.replacingOccurrences(of: ",", with: "")) ?? 0
        let actualAmt  = Double(actualAmountString.replacingOccurrences(of: ",", with: "")) ?? 0

        let newItem = PlannedExpense(context: context)
        newItem.id = newItem.id ?? UUID()
        newItem.descriptionText = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        newItem.plannedAmount = plannedAmt
        newItem.actualAmount = actualAmt
        newItem.transactionDate = transactionDate
        newItem.isGlobal = saveAsGlobalPreset
        newItem.budget = targetBudget

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
}
