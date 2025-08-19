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
    /// Prefill date for AddIncomeFormView; derived from the selected calendar date or today.
    @State private var addIncomeInitialDate: Date? = nil
    /// Holds the income being edited; presenting this non-nil value triggers the edit sheet.
    @State private var editingIncome: Income? = nil
    /// Controls which date the calendar should scroll to when navigation buttons are used.
    @State private var calendarScrollDate: Date? = Date()

    // MARK: Environment
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var themeManager: ThemeManager

    // MARK: View Model
    /// External owner should initialize and provide the view model; it manages selection and CRUD.
    @StateObject var viewModel = IncomeScreenViewModel()
    @AppStorage(AppSettingsKeys.calendarHorizontal.rawValue) private var calendarHorizontal: Bool = true
    @AppStorage(AppSettingsKeys.confirmBeforeDelete.rawValue) private var confirmBeforeDelete: Bool = true
    @State private var incomeToDelete: Income? = nil

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
        // Pull to refresh to reload entries for the selected day
        .refreshable { viewModel.reloadForSelectedDay() }
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
        // MARK: Present Edit Income Form (triggered by non-nil `editingIncome`)
        .sheet(item: $editingIncome, onDismiss: {
            // Reload after edit
            viewModel.reloadForSelectedDay()
        }) { income in
            AddIncomeFormView(
                incomeObjectID: income.objectID,
                budgetObjectID: nil,
                initialDate: nil
            )
        }
        .onAppear {
            // Ensure the calendar opens on today's date and load entries
            if viewModel.selectedDate == nil { viewModel.selectedDate = Date() }
            let initial = viewModel.selectedDate ?? Date()
            calendarScrollDate = initial
            viewModel.load(day: initial)
        }
        .background(themeManager.selectedTheme.background.ignoresSafeArea())
    }

    // MARK: - Calendar Section
    /// Wraps the `MCalendarView` in a card and applies a stark black & white appearance.
    /// In light mode the background is white; in dark mode it is black; selection styling handled by the calendar views.
    @ViewBuilder
    private var calendarSection: some View {
        let today = Date()
        let start = Calendar.current.date(byAdding: .year, value: -5, to: today)!
        let end = Calendar.current.date(byAdding: .year, value: 5, to: today)!
        VStack(spacing: 8) {
            HStack(spacing: 12) {
//                Button("<<") { goToPreviousMonth() }
//                Button("<") { goToPreviousDay() }
//                Button("Today") { goToToday() }
//                Button(">") { goToNextDay() }
//                Button(">>") { goToNextMonth() }
            }
#if os(macOS)
            .buttonStyle(.borderedProminent)
#else
            .buttonStyle(.bordered)
#endif
            .accentColor(themeManager.selectedTheme.accent)
            .tint(themeManager.selectedTheme.accent)
            .font(.subheadline)
            if calendarHorizontal {
                horizontalCalendarView(start: start, end: end)
            } else {
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
                        .startMonth(start)
                        .endMonth(end)
                        .scrollTo(date: calendarScrollDate)
                }
                .accessibilityIdentifier("IncomeCalendar")
                // MARK: Double-click calendar to add income (macOS)
                .simultaneousGesture(
                    TapGesture(count: 2).onEnded {
                        addIncomeInitialDate = viewModel.selectedDate ?? today
                        isPresentingAddIncome = true
                    }
                )
#else
                // iOS
                MCalendarView(
                    selectedDate: $viewModel.selectedDate,
                    selectedRange: .constant(nil)
                ) { config in
                    config
                        .monthLabel(UBMonthLabel.init)
                        .startMonth(start)
                        .endMonth(end)
                        .scrollTo(date: calendarScrollDate)
                }
                .accessibilityIdentifier("IncomeCalendar")
#endif
            }
        }
        .frame(maxWidth: .infinity)
        .layoutPriority(1)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .fill(themeManager.selectedTheme.secondaryBackground)
        )
    }

    // MARK: - Horizontal Calendar Implementation
    /// Provides a horizontal, paged calendar composed of individual months.
    /// Each month is its own `MCalendarView`, arranged in a `LazyHStack` within a horizontal `ScrollView`.
    @ViewBuilder
    private func horizontalCalendarView(start: Date, end: Date) -> some View {
        let months = monthsBetween(start: start, end: end)
        ScrollViewReader { proxy in
            GeometryReader { geo in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        ForEach(months, id: \.self) { month in
#if os(macOS)
                            MCalendarView(
                                selectedDate: $viewModel.selectedDate,
                                selectedRange: .constant(nil)
                            ) { config in
                                config
                                    .dayView(UBDayView.init)
                                    .weekdaysView(UBWeekdaysView.init)
                                    .monthLabel(UBMonthLabel.init)
                                    .startMonth(month)
                                    .endMonth(month)
                            }
#else
                            MCalendarView(
                                selectedDate: $viewModel.selectedDate,
                                selectedRange: .constant(nil)
                            ) { config in
                                config
                                    .monthLabel(UBMonthLabel.init)
                                    .startMonth(month)
                                    .endMonth(month)
                            }
#endif
                            .frame(width: geo.size.width)
                            .id(month)
                        }
                    }
                }
                .accessibilityIdentifier("IncomeCalendar")
#if os(macOS)
                .simultaneousGesture(
                    TapGesture(count: 2).onEnded {
                        addIncomeInitialDate = viewModel.selectedDate ?? Date()
                        isPresentingAddIncome = true
                    }
                )
#endif
                .onAppear {
                    if let date = calendarScrollDate {
                        proxy.scrollTo(startOfMonth(for: date), anchor: .center)
                    }
                }
            }
            .frame(height: 320)
        }
    }

    /// Returns first-of-month dates between `start` and `end` (inclusive).
    private func monthsBetween(start: Date, end: Date) -> [Date] {
        var months: [Date] = []
        var current = startOfMonth(for: start)
        let last = startOfMonth(for: end)
        while current <= last {
            months.append(current)
            current = Calendar.current.date(byAdding: .month, value: 1, to: current)!
        }
        return months
    }

    /// Returns the first day of the month containing `date`.
    private func startOfMonth(for date: Date) -> Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: date))!
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
        .alert(item: $incomeToDelete) { income in
            Alert(
                title: Text("Delete \(income.source ?? "Income")?"),
                message: Text("This will remove the income entry."),
                primaryButton: .destructive(Text("Delete")) { viewModel.delete(income: income) },
                secondaryButton: .cancel()
            )
        }
    }

    // MARK: - Calendar Navigation Helpers
    /// Updates the selected date and scroll target for the calendar.
    private func navigate(to date: Date) {
        viewModel.selectedDate = date
        calendarScrollDate = date
    }
    /// Scrolls to the first day of the previous month.
    private func goToPreviousMonth() {
        let cal = Calendar.current
        let current = viewModel.selectedDate ?? Date()
        if let startOfCurrent = cal.date(from: cal.dateComponents([.year, .month], from: current)),
           let prev = cal.date(byAdding: .month, value: -1, to: startOfCurrent) {
            navigate(to: prev)
        }
    }
    /// Moves selection to the previous day.
    private func goToPreviousDay() {
        let cal = Calendar.current
        let current = viewModel.selectedDate ?? Date()
        if let prev = cal.date(byAdding: .day, value: -1, to: current) {
            navigate(to: prev)
        }
    }
    /// Centers the calendar on today.
    private func goToToday() { navigate(to: Date()) }
    /// Moves selection to the next day.
    private func goToNextDay() {
        let cal = Calendar.current
        let current = viewModel.selectedDate ?? Date()
        if let next = cal.date(byAdding: .day, value: 1, to: current) {
            navigate(to: next)
        }
    }
    /// Scrolls to the first day of the next month.
    private func goToNextMonth() {
        let cal = Calendar.current
        let current = viewModel.selectedDate ?? Date()
        if let startOfCurrent = cal.date(from: cal.dateComponents([.year, .month], from: current)),
           let next = cal.date(byAdding: .month, value: 1, to: startOfCurrent) {
            navigate(to: next)
        }
    }

    // MARK: - Edit Flow Helpers
    /// Begins editing for a given income; sets state used by the edit sheet.
    /// - Parameter income: The Core Data `Income` instance to edit; its `objectID` is passed to the form.
    private func beginEditingIncome(_ income: Income) {
        editingIncome = income
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
        if confirmBeforeDelete, let first = targets.first {
            incomeToDelete = first
        } else {
            targets.forEach { viewModel.delete(income: $0) }
        }
    }
}

// MARK: - IncomeRow
/// A compact row showing source and amount; applies the unified swipe actions.
private struct IncomeRow: View {

    // MARK: Properties
    let income: Income
    let onEdit: () -> Void
    let onDelete: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    @AppStorage(AppSettingsKeys.confirmBeforeDelete.rawValue) private var confirmBeforeDelete: Bool = true
    @State private var showDeleteAlert = false

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
            UnifiedSwipeConfig(editTint: themeManager.selectedTheme.secondaryAccent),
            onEdit: onEdit,
            onDelete: {
                if confirmBeforeDelete {
                    showDeleteAlert = true
                } else {
                    onDelete()
                }
            }
        )
        .alert("Delete Income?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) { }
        }
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
