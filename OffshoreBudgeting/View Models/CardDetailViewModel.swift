//
//  CardDetailViewModel.swift
//  SoFar
//
//  Shows advanced details for a single Card:
//  - Total variable spend
//  - Breakdown by ExpenseCategory
//  - List of expenses with search
//

import Foundation
import SwiftUI
import CoreData

// MARK: - CardCategoryTotal
struct CardCategoryTotal: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let amount: Double
    let colorHex: String?
    
    var color: Color {
        Color(hex: colorHex) ?? .secondary
    }
}

// MARK: - CardExpense
/// Unified expense model for card details, combining planned and unplanned expenses.
struct CardExpense: Identifiable, Hashable {
    let objectID: NSManagedObjectID?
    let uuid: UUID?
    let description: String
    let amount: Double
    let date: Date?
    let category: ExpenseCategory?
    let isPlanned: Bool

    var id: String {
        if let oid = objectID { return oid.uriRepresentation().absoluteString }
        if let uuid { return "uuid:\(uuid.uuidString)" }
        return "temp:\(description)\(date?.timeIntervalSince1970 ?? 0)"
    }
}

// MARK: - CardDetailLoadState
enum CardDetailLoadState: Equatable {
    case initial
    case loading
    case loaded(total: Double, categories: [CardCategoryTotal], expenses: [CardExpense])
    case empty
    case error(String)
}

// MARK: - CardDetailViewModel
@MainActor
final class CardDetailViewModel: ObservableObject {
    
    // MARK: Inputs
    let card: CardItem
    let allowedInterval: DateInterval?   // nil = all time
    
    // MARK: Services
    private let unplannedService = UnplannedExpenseService()
    private let plannedService = PlannedExpenseService()
    
    // MARK: Outputs
    @Published var state: CardDetailLoadState = .initial
    @Published var searchText: String = ""

    // Filtered view of expenses
    var filteredExpenses: [CardExpense] {
        guard case .loaded(_, _, let expenses) = state else { return [] }
        guard !searchText.isEmpty else { return expenses }

        let q = searchText.lowercased()
        let df = DateFormatter()
        df.dateStyle = .medium

        return expenses.filter { exp in
            if exp.description.lowercased().contains(q) { return true }
            if let date = exp.date, df.string(from: date).lowercased().contains(q) { return true }
            if let name = exp.category?.name?.lowercased(), name.contains(q) { return true }
            return false
        }
    }

    /// Category totals derived from the currently filtered expenses
    var filteredCategories: [CardCategoryTotal] {
        guard case .loaded = state else { return [] }
        return buildCategories(from: filteredExpenses)
    }
    
    // MARK: Init
    init(card: CardItem, allowedInterval: DateInterval? = nil) {
        self.card = card
        self.allowedInterval = allowedInterval
    }
    
    // MARK: load()
    func load() async {
        guard let uuid = card.uuid else {
            state = .error("Missing card ID")
            return
        }
        state = .loading
        do {
            let unplanned = try unplannedService.fetchForCard(uuid, in: allowedInterval, sortedByDateAscending: false)
            let planned: [PlannedExpense]
            if let interval = allowedInterval {
                planned = try plannedService.fetchForCard(uuid, in: interval, sortedByDateAscending: false)
            } else {
                planned = try plannedService.fetchForCard(uuid, sortedByDateAscending: false)
            }

            let mappedUnplanned: [CardExpense] = unplanned.map { exp in
                let desc = (exp.value(forKey: "descriptionText") as? String)
                    ?? (exp.value(forKey: "title") as? String) ?? ""
                let uuid = exp.value(forKey: "id") as? UUID
                let cat = exp.value(forKey: "expenseCategory") as? ExpenseCategory
                return CardExpense(objectID: exp.objectID,
                                   uuid: uuid,
                                   description: desc,
                                   amount: exp.value(forKey: "amount") as? Double ?? 0,
                                   date: exp.value(forKey: "transactionDate") as? Date,
                                   category: cat,
                                   isPlanned: false)
            }

            let mappedPlanned: [CardExpense] = planned.map { exp in
                let desc = (exp.value(forKey: "descriptionText") as? String)
                    ?? (exp.value(forKey: "title") as? String) ?? ""
                let uuid = exp.value(forKey: "id") as? UUID
                let cat = exp.expenseCategory
                let amount = exp.actualAmount != 0 ? exp.actualAmount : exp.plannedAmount
                return CardExpense(objectID: exp.objectID,
                                   uuid: uuid,
                                   description: desc,
                                   amount: amount,
                                   date: exp.transactionDate,
                                   category: cat,
                                   isPlanned: true)
            }

            let combined = (mappedUnplanned + mappedPlanned).sorted { (a, b) in
                let ad = a.date ?? .distantPast
                let bd = b.date ?? .distantPast
                return ad > bd
            }

            if combined.isEmpty {
                state = .empty
                return
            }

            let total = combined.reduce(0) { $0 + $1.amount }
            let categories = buildCategories(from: combined)
            state = .loaded(total: total, categories: categories, expenses: combined)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    /// Builds category totals from a list of expenses
    private func buildCategories(from expenses: [CardExpense]) -> [CardCategoryTotal] {
        var buckets: [String: (amount: Double, colorHex: String?)] = [:]
        for exp in expenses {
            let amount = exp.amount
            let name = exp.category?.name ?? "Uncategorized"
            let hex = exp.category?.color
            let current = buckets[name] ?? (0, hex)
            buckets[name] = (current.amount + amount, current.colorHex ?? hex)
        }
        return buckets
            .map { CardCategoryTotal(name: $0.key, amount: $0.value.amount, colorHex: $0.value.colorHex) }
            .sorted { $0.amount > $1.amount }
    }
}
