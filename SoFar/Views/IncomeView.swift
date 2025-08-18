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
/// Shows a calendar (MijickCalendarView). Tap a date to add income (Planned/Actual; optional recurrence).
/// Below the calendar, displays incomes for the selected day with edit/delete.
/// A weekly summary bar shows total income for the current week.
struct IncomeView: View {

    // MARK: State
    /// Controls the Add Income sheet presentation.
    @State private var isPresentingAddIncome: Bool = false
    /// Controls the Edit Income sheet presentation.
    @State private var isPresentingEditIncome: Bool = false
    /// Prefill date for AddIncomeFormView; derived from the selected calendar date or today.
    @State private var addIncomeInitialDate: Date? = nil
    /// Holds the objectID of the income being edited; used to prefill the edit sheet.
    @State private var editingIncomeObjectID: NSManagedObjectID? = nil

    // MARK: Environment
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var themeManager: ThemeManager

    // MARK: View Model
    /// External owner should initialize and provide the view model; it manages selection and CRUD.
    @StateObject var viewModel = IncomeScreenViewModel()

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
        .frame(maxHeight: .infinity, alignment: .top)
        .navigationTitle("Income")
        // MARK: Toolbar (+ button) → Present Add Income sheet
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    addIncomeInitialDate = viewModel.selectedDate ?? Date()
                    isPresentingAddIncome = true
                } label: {
                    Label("Add Income", systemImage: "plus")
                }
                .accessibilityIdentifier("add_income_button")
            }
        }
        // Keep list in sync without deprecated APIs
        .modifier(SelectionChangeHandler(viewModel: viewModel))
        // MARK: Present Add Income Form
        .sheet(isPresented: $isPresentingAddIncome, onDismiss: {
            // Reload entries for the selected day after adding/saving
            viewModel.reloadForSelectedDay()
        }) {
            AddIncomeFormView(
                incomeObjectID: nil,
                budgetObjectID: nil,
                initialDate: addIncomeInitialDate
            )
        }
        // MARK: Present Edit Income Form
        .sheet(isPresented: $isPresentingEditIncome, onDismiss: {
            // Reload after edit
            viewModel.reloadForSelectedDay()
            editingIncomeObjectID = nil
        }) {
            AddIncomeFormView(
                incomeObjectID: editingIncomeObjectID,
                budgetObjectID: nil,
                initialDate: nil
            )
        }
        .onAppear {
            // Initial load (today or previously selected date)
            viewModel.load(day: viewModel.selectedDate ?? Date())
        }
        .background(themeManager.selectedTheme.background.ignoresSafeArea())
    }

    // MARK: - Calendar Section
    /// Wraps the `MCalendarView` in a card and applies a stark black & white appearance.
    /// In light mode the background is white; in dark mode it is black; selection styling handled by the calendar views.
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
        .frame(maxWidth: .infinity)
        .layoutPriority(1)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .fill(themeManager.selectedTheme.secondaryBackground)
        )
        .accessibilityIdentifier("IncomeCalendar")
        // MARK: Double-click calendar to add income (macOS)
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                addIncomeInitialDate = viewModel.selectedDate ?? Date()
                isPresentingAddIncome = true
            }
        )
        #else
        // iOS
        MCalendarView(
            selectedDate: $viewModel.selectedDate,
            selectedRange: .constant(nil)
        ) { config in
            // iOS: use library defaults for Day/Weekdays/Month appearances
            config
        }
        .frame(maxWidth: .infinity)
        .layoutPriority(1)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .fill(themeManager.selectedTheme.secondaryBackground)
        )
        .accessibilityIdentifier("IncomeCalendar")
        #endif
    }

    // MARK: - Weekly Summary Bar
    /// Small bar that totals the week containing the selected date.
    @ViewBuilder
    private var weeklySummaryBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar").imageScale(.large)
            VStack(alignment: .leading, spacing: 4) {
                let (start, end) = weekBounds(for: viewModel.selectedDate ?? Date())
                Text("\(formattedDate(start)) – \(formattedDate(end))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(currencyString(for: viewModel.totalForSelectedDate))
                    .font(.headline)
            }
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .fill(themeManager.selectedTheme.secondaryBackground)
                .shadow(radius: 1, y: 1)
        )
    }

    // MARK: - Selected Day Section (WITH swipe to delete & edit)
    /// Displays the selected date and a list of income entries for that day.
    /// The list supports native swipe actions; it also scrolls when tall; pill styling preserved.
    private var selectedDaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            let date = viewModel.selectedDate ?? Date()
            let entries: [Income] = viewModel.incomesForDay   // Explicit type trims solver work

            // MARK: Section Title — Selected Day
            Text(DateFormatter.localizedString(from: date, dateStyle: .full, timeStyle: .none))
                .font(.headline)
                .padding(.bottom, DS.Spacing.xs)

            if entries.isEmpty {
                // MARK: Empty State
                Text("No income for \(formattedDate(date)).")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                    .padding(.vertical, 4)
            } else {
                // MARK: Scrollable List with Unified Swipe Actions
                List {
                    ForEach(entries, id: \.objectID) { income in
                        IncomeRow(
                            income: income,
                            onEdit: { beginEditingIncome(income) },            // ⟵ FIX: local helper; no VM dynamic member
                            onDelete: { viewModel.delete(income: income) }
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    .onDelete { indexSet in
                        handleDelete(indexSet, in: entries)
                    }
                }
                .listStyle(.plain)
                #if os(iOS)
                .scrollIndicators(.hidden)
                #endif
                .applyIfAvailableScrollContentBackgroundHidden()
                .frame(minHeight: 50, maxHeight: 100) // compact pill; scroll when needed
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .fill(themeManager.selectedTheme.secondaryBackground)
                .shadow(radius: 1, y: 1)
        )
    }

    // MARK: - Edit Flow Helpers
    /// Begins editing for a given income; sets state used by the edit sheet.
    /// - Parameter income: The Core Data `Income` instance to edit; its `objectID` is passed to the form.
    private func beginEditingIncome(_ income: Income) {
        editingIncomeObjectID = income.objectID
        isPresentingEditIncome = true
    }

    // MARK: - Formatting Helpers
    /// Formats a date for short UI display; e.g., "Aug 14, 2025".
    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }

    /// Computes the start/end of the week containing `date` using the current calendar and locale.
    private func weekBounds(for date: Date) -> (start: Date, end: Date) {
        let cal = Calendar.current
        if let interval = cal.dateInterval(of: .weekOfYear, for: date) {
            return (interval.start, interval.end)
        }
        let weekday = cal.component(.weekday, from: date)
        let deltaToStart = (weekday - cal.firstWeekday + 7) % 7
        let start = cal.date(byAdding: .day, value: -deltaToStart, to: date) ?? date
        let end = cal.date(byAdding: .day, value: 7 - deltaToStart, to: start) ?? date
        return (start, end)
    }

    /// Locale-aware currency string for display.
    private func currencyString(for amount: Double) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.locale = .current
        return nf.string(from: amount as NSNumber) ?? String(format: "%.2f", amount)
    }

    // MARK: - Delete Handler
    /// Handles deleting selected rows from the day's entries.
    /// - Parameters:
    ///   - indexSet: The set of indices from the `List` to delete.
    ///   - entries: A snapshot array used by the current `ForEach`.
    private func handleDelete(_ indexSet: IndexSet, in entries: [Income]) {
        let targets = indexSet.compactMap { entries.indices.contains($0) ? entries[$0] : nil }
        targets.forEach { viewModel.delete(income: $0) }
    }
}

// MARK: - IncomeRow
/// A compact row showing source and amount; applies the unified swipe actions.
private struct IncomeRow: View {

    // MARK: Properties
    let income: Income
    let onEdit: () -> Void
    let onDelete: () -> Void

    // MARK: Body
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(income.source ?? "—")
                    .font(.headline)
                Text(currencyString(for: income.amount))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 6)
        // Consistent: slow drag reveals Edit + Delete; full swipe commits Delete on iOS/iPadOS.
        .unifiedSwipeActions(
            .standard,
            onEdit: onEdit,
            onDelete: onDelete
        )
    }

    // MARK: Helpers
    private func currencyString(for amount: Double) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.locale = .current
        return nf.string(from: amount as NSNumber) ?? String(format: "%.2f", amount)
    }
}

// MARK: - SelectionChangeHandler
/// Bridges `onChange` without deprecated macOS 14 signatures; reloads when selectedDate changes.
/// Behavior: Calls `viewModel.reloadForSelectedDay()` whenever `selectedDate` changes.
private struct SelectionChangeHandler: ViewModifier {
    @ObservedObject var viewModel: IncomeScreenViewModel
    func body(content: Content) -> some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            return content.onChange(of: viewModel.selectedDate) {
                viewModel.reloadForSelectedDay()
            }
        } else {
            return content.onChange(of: viewModel.selectedDate) { _ in
                viewModel.reloadForSelectedDay()
            }
        }
    }
}

// MARK: - Array Safe Indexing (for onDelete index safety)
private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Availability Helpers
private extension View {
    /// Hides list background on supported OS versions; no-ops on older targets.
    @ViewBuilder
    func applyIfAvailableScrollContentBackgroundHidden() -> some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}
