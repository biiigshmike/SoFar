//
//  IncomeScreenViewModel.swift
//  SoFar
//
//  Holds selected date, fetches incomes for the date, and performs CRUD via IncomeService.
//

import Foundation
import CoreData

// MARK: - IncomeScreenViewModel
@MainActor
final class IncomeScreenViewModel: ObservableObject {
    // MARK: Public, @Published
    @Published var selectedDate: Date? = nil
    @Published private(set) var incomesForDay: [Income] = []
    @Published private(set) var totalForSelectedDate: Double = 0
    
    // MARK: Private
    private let incomeService: IncomeService
    private let calendar: Calendar = .current
    
    // MARK: Init
    init(incomeService: IncomeService = IncomeService()) {
        self.incomeService = incomeService
    }
    
    // MARK: Titles
    var selectedDateTitle: String {
        guard let d = selectedDate else { return "—" }
        return DateFormatter.localizedString(from: d, dateStyle: .full, timeStyle: .none)
    }
    
    var totalForSelectedDateText: String {
        NumberFormatter.currency.string(from: totalForSelectedDate as NSNumber) ?? ""
    }
    
    // MARK: Loading
    func reloadForSelectedDay() {
        guard let d = selectedDate else { return }
        load(day: d)
    }
    
    func load(day: Date) {
        do {
            incomesForDay = try incomeService.fetchIncomes(on: day)
            totalForSelectedDate = incomesForDay.reduce(0) { $0 + $1.amount }
        } catch {
            #if DEBUG
            print("Income fetch error:", error)
            #endif
            incomesForDay = []
            totalForSelectedDate = 0
        }
    }
    
    // MARK: CRUD
    func delete(income: Income) {
        do {
            try incomeService.deleteIncome(income)
            let day = selectedDate ?? income.date ?? Date()
            load(day: day)
        } catch {
            #if DEBUG
            print("Income delete error:", error)
            #endif
        }
    }
    
    // MARK: Formatting
    func currencyString(for amount: Double) -> String {
        NumberFormatter.currency.string(from: amount as NSNumber) ?? String(format: "%.2f", amount)
    }
}

// MARK: - Currency NumberFormatter
private extension NumberFormatter {
    static let currency: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        return f
    }()
}
