//
//  BudgetDetailsViewModelStore.swift
//  SoFar
//
//  Keeps a single BudgetDetailsViewModel instance per Budget objectID so that
//  SwiftUI view reconstruction does not recreate the view model and re-run
//  load() unnecessarily. This eliminates re-entrant load loops for empty budgets
//  where identity can briefly churn during initial setup.
//

import Foundation
import CoreData

@MainActor
final class BudgetDetailsViewModelStore {
    static let shared = BudgetDetailsViewModelStore()

    private var cache: [NSManagedObjectID: BudgetDetailsViewModel] = [:]

    func viewModel(for budgetID: NSManagedObjectID,
                   context: NSManagedObjectContext = CoreDataService.shared.viewContext) -> BudgetDetailsViewModel {
        if let existing = cache[budgetID] {
            AppLog.viewModel.debug("BudgetDetailsViewModelStore reuse – id: \(budgetID)")
            return existing
        }
        let vm = BudgetDetailsViewModel(budgetObjectID: budgetID, context: context)
        AppLog.viewModel.debug("BudgetDetailsViewModelStore create – id: \(budgetID)")
        cache[budgetID] = vm
        return vm
    }
}
