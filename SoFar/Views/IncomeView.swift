//
//  IncomeView.swift
//  SoFar
//
//  Created by Michael Brown on 8/11/25.
//

import SwiftUI
import MijickCalendarView
import CoreData
import Combine

// MARK: - IncomeView
/// Shows a calendar (MijickCalendarView). Tap a date to add income (Planned/Actual, optional recurrence).
/// Below the calendar, displays incomes for the selected day with edit/delete.
/// A weekly summary bar shows total income for the current week.
struct IncomeView: View {
    // MARK: State & ViewModel
    @StateObject private var viewModel = IncomeScreenViewModel()
    private let incomeService = IncomeService()

    // MARK: Presentation State
    /// Controls the Add Income sheet.
    @State private var isPresentingAddIncome: Bool = false
    /// If you want to pre-fill the Add form with the currently selected date in the future,
    /// store it here. (The current AddIncomeFormView defaults to "today"; we can thread this later.)
    @State private var addIncomeInitialDate: Date? = nil

    // MARK: Environment
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.managedObjectContext) private var viewContext

    // MARK: Body
    var body: some View {
        VStack(spacing: 12) {
            // Calendar section in a padded card
            calendarSection

            // Weekly summary bar
            weeklySummaryBar

            // Selected day entries
            selectedDaySection
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        // Allow the calendar to grow and fill available vertical space.
        .frame(maxHeight: .infinity, alignment: .top)
        .navigationTitle("Income")
        // MARK: Toolbar (+ button) → Present Add Income sheet
        .appToolbar(
            titleDisplayMode: .large,
            trailingItems: [
                .add {
                    // MARK: + Button Action
                    // Capture the currently selected day (or today) for possible future prefill.
                    addIncomeInitialDate = viewModel.selectedDate ?? Date()
                    isPresentingAddIncome = true
                }
            ]
        )
        // MARK: Watch date changes → keep list in sync on both iOS/macOS without deprecated APIs
        .modifier(SelectionChangeHandler(viewModel: viewModel))
        // MARK: Present Add Income Form
        .sheet(isPresented: $isPresentingAddIncome, onDismiss: {
            // Reload entries for the selected day after adding/saving
            viewModel.reloadForSelectedDay()
        }) {
            // NOTE: Current AddIncomeFormView doesn’t take an initial date.
            // If you want that, I can extend it to accept `initialDate` and set its VM on appear.
            AddIncomeFormView(incomeObjectID: nil, budgetObjectID: nil)
        }
        .onAppear {
            // Initial load (today or previously selected date)
            viewModel.load(day: viewModel.selectedDate ?? Date())
        }
    }
    
    // MARK: Calendar Section
    /// Wraps the `MCalendarView` in a card and applies a stark black and white appearance.
    /// In light mode the background is white with a black selection circle; in dark mode the
    /// background is black with a white selection circle. The calendar has a fixed height to
    /// prevent expansion on larger screens.
    @ViewBuilder
    private var calendarSection: some View {
        #if os(macOS)
        // macOS: attach the configuration closure directly to the call
        MCalendarView(
            selectedDate: $viewModel.selectedDate,
            selectedRange: .constant(nil)
        ) { config in
            config
                .dayView(UBDayView.init)
                .weekdaysView(UBWeekdaysView.init)
                .monthLabel(UBMonthLabel.init)
        }
        .frame(maxWidth: CGFloat.infinity)
        .layoutPriority(1)                   // grow vertically when there’s space
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .fill(colorScheme == .dark ? Color.black : Color.white)
        )
        .accessibilityIdentifier("IncomeCalendar")
        // MARK: Double-tap calendar to add income
        .onTapGesture(count: 2) {
            addIncomeInitialDate = viewModel.selectedDate ?? Date()
            isPresentingAddIncome = true
        }
        #else
        // iOS: default look; keep foreground for clarity
        MCalendarView(
            selectedDate: $viewModel.selectedDate,
            selectedRange: .constant(nil)
        )
        .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
        .frame(maxWidth: CGFloat.infinity)
        .layoutPriority(1)                   // grow vertically when there’s space
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .fill(colorScheme == .dark ? Color.black : Color.white)
        )
        .accessibilityIdentifier("IncomeCalendar")
        // MARK: Double-tap calendar to add income
        .onTapGesture(count: 2) {
            addIncomeInitialDate = viewModel.selectedDate ?? Date()
            isPresentingAddIncome = true
        }
        #endif
    }
    
    // MARK: Weekly Summary Bar
    /// Shows the total income amount for the week containing the selected date.  It computes
    /// the total using `IncomeService` rather than an unavailable `weekTotals(for:)` API.
    private var weeklySummaryBar: some View {
        // Compute weekly total using IncomeService
        let targetDate = viewModel.selectedDate ?? Date()
        let calendar = Calendar.current
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: targetDate)
            ?? DateInterval(start: calendar.startOfDay(for: targetDate), duration: 60 * 60 * 24 * 7)
        let weeklyTotal = (try? incomeService.totalAmount(in: weekInterval)) ?? 0

        return HStack(spacing: DS.Spacing.m) {
            summaryPill(title: "This Week", amount: viewModel.currencyString(for: weeklyTotal))
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .fill(colorScheme == .dark ? Color.black : Color.white)
        )
    }
    
    // MARK: Selected Day Section
    /// Lists all incomes for the currently selected day.  Uses `incomesForDay` instead of a
    /// nonexistent `entries(on:)` API.
    private var selectedDaySection: some View {
        let date = viewModel.selectedDate ?? Date()
        let entries = viewModel.incomesForDay

        return VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text(DateFormatter.localizedString(from: date, dateStyle: .full, timeStyle: .none))
                .font(.headline)
                .padding(.bottom, DS.Spacing.xs)

            if entries.isEmpty {
                Text("No income for \(formattedDate(date)).")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(entries) { income in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(income.source ?? "—")
                                .font(.body)
                            Text(formattedDate(income.date))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(viewModel.currencyString(for: income.amount))
                            .font(.body.monospacedDigit())
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.card)
                            .strokeBorder(Color.secondary.opacity(0.25))
                    )
                }
            }
        }
    }
    
    // MARK: Summary Pill
    /// Creates a small pill with a label and a currency amount.
    private func summaryPill(title: String, amount: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(amount)
                .font(.headline.monospacedDigit())
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(colorScheme == .dark ? Color.black : Color.white)
        )
    }
    
    // MARK: Date Formatting Helper
    /// Formats a date for display in the income list.  `Income.date` is optional, so a placeholder is returned if nil.
    private func formattedDate(_ date: Date?) -> String {
        guard let date else { return "—" }
        return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none)
    }
    
    // MARK: Editor Commit Handler (legacy; retained if you still use the old editor elsewhere)
    /// Handles actions from the editor and decides if the sheet should dismiss.
    private func handleEditorCommit(_ action: IncomeEditorAction) -> Bool {
        switch action {
        case .cancelled:
            return true
        case .created(let source, let amount, let date, let isPlanned, let recurrence, let endDate, let secondDay):
            do {
                _ = try incomeService.createIncome(source: source,
                                                   amount: amount,
                                                   date: date,
                                                   isPlanned: isPlanned,
                                                   recurrence: recurrence,
                                                   recurrenceEndDate: endDate,
                                                   secondBiMonthlyDay: secondDay)
                viewModel.selectedDate = date
                viewModel.reloadForSelectedDay()
                return true
            } catch {
                #if DEBUG
                print("Create income error:", error)
                #endif
                return false
            }
        case .updated(let income, let source, let amount, let date, let isPlanned, let recurrence, let endDate, let secondDay):
            do {
                try incomeService.updateIncome(income,
                                               source: source,
                                               amount: amount,
                                               date: date,
                                               isPlanned: isPlanned,
                                               recurrence: recurrence,
                                               recurrenceEndDate: endDate,
                                               secondBiMonthlyDay: secondDay)
                viewModel.selectedDate = date
                viewModel.reloadForSelectedDay()
                return true
            } catch {
                #if DEBUG
                print("Update income error:", error)
                #endif
                return false
            }
        }
    }
}

// MARK: - Editor Mode
/// Whether we are adding for a specific date or editing an existing income.
enum IncomeEditorMode {
    case add(date: Date)
    case edit
}

// MARK: - SelectionChangeHandler (ViewModifier)
/// Cross-platform handler for `selectedDate` changes without using deprecated `onChange` overloads.
private struct SelectionChangeHandler: ViewModifier {
    @ObservedObject var viewModel: IncomeScreenViewModel
    
    func body(content: Content) -> some View {
        if #available(iOS 17, macOS 14, *) {
            content.onChange(of: viewModel.selectedDate) { _, newValue in
                guard let date = newValue else { return }
                viewModel.load(day: date)
            }
        } else {
            content.onReceive(viewModel.$selectedDate.removeDuplicates()) { newValue in
                guard let date = newValue else { return }
                viewModel.load(day: date)
            }
        }
    }
}
