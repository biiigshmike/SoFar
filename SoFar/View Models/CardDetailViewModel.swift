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

// MARK: - CardDetailLoadState
enum CardDetailLoadState: Equatable {
    case initial
    case loading
    case loaded(total: Double, categories: [CardCategoryTotal], expenses: [UnplannedExpense])
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
    private let expenseService = UnplannedExpenseService()
    
    // MARK: Outputs
    @Published var state: CardDetailLoadState = .initial
    @Published var searchText: String = ""
    
    // Filtered view of expenses
    var filteredExpenses: [UnplannedExpense] {
        guard case .loaded(_, _, let expenses) = state else { return [] }
        guard !searchText.isEmpty else { return expenses }
        
        let q = searchText.lowercased()
        let df = DateFormatter()
        df.dateStyle = .medium
        
        return expenses.filter { exp in
            // Title/description: prefer descriptionText, fallback to legacy "title"
            let title = (exp.value(forKey: "descriptionText") as? String)
                ?? (exp.value(forKey: "title") as? String)
                ?? ""
            if title.lowercased().contains(q) { return true }
            
            if let date = exp.value(forKey: "transactionDate") as? Date,
               df.string(from: date).lowercased().contains(q) {
                return true
            }
            if let cat = exp.value(forKey: "expenseCategory") as? ExpenseCategory,
               let name = cat.name?.lowercased(), name.contains(q) {
                return true
            }
            return false
        }
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
            // Expenses
            let expenses = try expenseService.fetchForCard(uuid, in: allowedInterval, sortedByDateAscending: false)
            if expenses.isEmpty {
                state = .empty
                return
            }
            
            // Total
            let total: Double
            if let window = allowedInterval {
                total = try expenseService.totalForCard(uuid, in: window)
            } else {
                total = expenses.reduce(0) { $0 + (expValue(expenses: $1)) }
            }
            
            // Category totals
            var buckets: [String: (amount: Double, colorHex: String?)] = [:]
            for exp in expenses {
                let amount = expValue(expenses: exp)
                var name = "Uncategorized"
                var hex: String? = nil
                if let cat = exp.value(forKey: "expenseCategory") as? ExpenseCategory {
                    name = cat.name ?? "Uncategorized"
                    hex = cat.color
                }
                let current = buckets[name] ?? (0, hex)
                buckets[name] = (current.amount + amount, current.colorHex ?? hex)
            }
            let categories = buckets
                .map { CardCategoryTotal(name: $0.key, amount: $0.value.amount, colorHex: $0.value.colorHex) }
                .sorted { $0.amount > $1.amount }
            
            state = .loaded(total: total, categories: categories, expenses: expenses)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}

private func expValue(expenses exp: UnplannedExpense) -> Double {
    exp.value(forKey: "amount") as? Double ?? 0
}
