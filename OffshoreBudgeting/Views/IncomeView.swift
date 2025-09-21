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
#if os(iOS)
import UIKit
#endif

/// Wrapper to provide `Identifiable` conformance for sheet presentation.
private struct AddIncomeSheetDate: Identifiable {
    let id = UUID()
    let value: Date
}

// MARK: - IncomeView
/// Shows a calendar (MijickCalendarView). Tap a date to add income (Planned/Actual; optional recurrence).
/// Below the calendar, displays incomes for the selected day with edit/delete.
/// A weekly summary bar shows total income for the current week.
struct IncomeView: View {

    // MARK: State
    /// Prefill date for AddIncomeFormView; derived from the selected calendar date or today.
    @State private var addIncomeInitialDate: AddIncomeSheetDate? = nil
    /// Holds the income being edited; presenting this non-nil value triggers the edit sheet.
    @State private var editingIncome: Income? = nil
    /// Controls which date the calendar should scroll to when navigation buttons are used.
    /// A `nil` value means no programmatic scroll is requested.
    @State private var calendarScrollDate: Date? = nil

    // MARK: Environment
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var themeManager: ThemeManager

    // MARK: View Model
    /// External owner should initialize and provide the view model; it manages selection and CRUD.
    @StateObject var viewModel = IncomeScreenViewModel()
    @AppStorage(AppSettingsKeys.calendarHorizontal.rawValue) private var calendarHorizontal: Bool = true
    @AppStorage(AppSettingsKeys.confirmBeforeDelete.rawValue) private var confirmBeforeDelete: Bool = true
    @State private var incomeToDelete: Income? = nil
    @State private var showDeleteAlert: Bool = false
    @State private var showDeleteOptions: Bool = false

#if os(iOS)
    /// Ensures the calendar makes fuller use of vertical space on compact devices like iPhone.
    /// Caps the minimum height to roughly half of the active screen so shorter devices don’t lose
    /// the sections below the calendar while taller devices keep the spacious layout.
    private var calendarCardMinimumHeight: CGFloat {
        let base: CGFloat = 380
        let screenHeight = UIScreen.main.bounds.height
        let adaptiveCap = screenHeight * 0.5
        return max(320, min(base, adaptiveCap))
    }
#endif

    // MARK: Calendar
    /// Calendar configured to begin weeks on Sunday.
    private var sundayFirstCalendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 1 // 1 = Sunday
        return calendar
    }

    // MARK: Body
    var body: some View {
        contentContainer
        // Keep list in sync without deprecated APIs
            .ub_onChange(of: viewModel.selectedDate) {
                viewModel.reloadForSelectedDay(forceMonthReload: false)
            }
        // MARK: Present Add Income Form
            .sheet(item: $addIncomeInitialDate, onDismiss: {
                // Reload entries for the selected day after adding/saving
                viewModel.reloadForSelectedDay(forceMonthReload: true)
            }) { item in
                AddIncomeFormView(
                    incomeObjectID: nil,
                    budgetObjectID: nil,
                    initialDate: item.value
                )
            }
        // MARK: Present Edit Income Form (triggered by non-nil `editingIncome`)
            .sheet(item: $editingIncome, onDismiss: {
                // Reload after edit
                viewModel.reloadForSelectedDay(forceMonthReload: true)
            }) { income in
                AddIncomeFormView(
                    incomeObjectID: income.objectID,
                    budgetObjectID: nil,
                    initialDate: nil
                )
            }
            .onAppear {
                // Ensure the calendar opens on today's date and load entries
                let initial = viewModel.selectedDate ?? Date()
                navigate(to: initial)
            }
            .ub_tabNavigationTitle("Income")
            .ub_surfaceBackground(
                themeManager.selectedTheme,
                configuration: themeManager.glassConfiguration,
                ignoringSafeArea: .all
            )
        // MARK: Toolbar (+ button) → Present Add Income sheet
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        addIncomeInitialDate = AddIncomeSheetDate(value: viewModel.selectedDate ?? Date())
                    } label: {
                        Label("Add Income", systemImage: "plus")
                    }
                    .accessibilityIdentifier("add_income_button")
                }
            }
    }

    // MARK: Layout Containers
    @ViewBuilder
    private var contentContainer: some View {
#if os(iOS)
        ScrollView {
            contentBody
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .ub_hideScrollIndicators()
        .refreshable { viewModel.reloadForSelectedDay(forceMonthReload: true) }
#else
        contentBody
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .top)
#endif
    }

    private var contentBody: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
#if os(macOS) || targetEnvironment(macCatalyst)
            Text("Income")
                .font(.largeTitle.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
#else
            Text("Income")
                .font(.system(.largeTitle, design: .default).weight(.bold))
                .frame(maxWidth: .infinity, alignment: .leading)
#endif

            VStack(spacing: 12) {
                // Calendar section in a padded card
                calendarSection

                // Weekly summary bar
                weeklySummaryBar

                // Selected day entries
                selectedDaySection
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Calendar Section
    /// Wraps the `MCalendarView` in a card and applies a stark black & white appearance.
    /// In light mode the background is white; in dark mode it is black; selection styling handled by the calendar views.
    @ViewBuilder
    private var calendarSection: some View {
        let today = Date()
        let cal = sundayFirstCalendar
        let start = cal.date(byAdding: .year, value: -5, to: today)!
        let end = cal.date(byAdding: .year, value: 5, to: today)!
        VStack(spacing: 8) {
            HStack(spacing: DS.Spacing.s) {
                Button("<<") { goToPreviousMonth() }
                    .accessibilityLabel("Previous Month")
                    .buttonStyle(CalendarNavigationButtonStyle(role: .icon))

                Button("<") { goToPreviousDay() }
                    .accessibilityLabel("Previous Day")
                    .buttonStyle(CalendarNavigationButtonStyle(role: .icon))

                Button("Today") { goToToday() }
                    .accessibilityLabel("Jump to Today")
                    .buttonStyle(CalendarNavigationButtonStyle(role: .label))

                Button(">") { goToNextDay() }
                    .accessibilityLabel("Next Day")
                    .buttonStyle(CalendarNavigationButtonStyle(role: .icon))

                Button(">>") { goToNextMonth() }
                    .accessibilityLabel("Next Month")
                    .buttonStyle(CalendarNavigationButtonStyle(role: .icon))
            }
            #if os(macOS)
            // macOS: attach the configuration closure directly to the call
            MCalendarView(
                selectedDate: $viewModel.selectedDate,
                selectedRange: .constant(nil)
            ) { config in
                config
                    .dayView { date, isCurrentMonth, selectedDate, selectedRange in
                        UBDayView(
                            date: date,
                            isCurrentMonth: isCurrentMonth,
                            selectedDate: selectedDate,
                            selectedRange: selectedRange,
                            summary: viewModel.summary(for: date),
                            selectedOverride: viewModel.selectedDate
                        )
                    }
                    .firstWeekday(.sunday)
                    .weekdaysView(UBWeekdaysView.init)
                    .monthLabel(UBMonthLabel.init)
                    .startMonth(start)
                    .endMonth(end)
                    .scrollTo(date: calendarScrollDate)
            }
            .transaction { t in
                t.animation = nil
                t.disablesAnimations = true
            }
            .animation(nil, value: viewModel.selectedDate)
            .animation(nil, value: calendarScrollDate)
            .accessibilityIdentifier("IncomeCalendar")
            // MARK: Double-click calendar to add income (macOS)
            .simultaneousGesture(
                TapGesture(count: 2).onEnded {
                    addIncomeInitialDate = AddIncomeSheetDate(value: viewModel.selectedDate ?? today)
                }
            )
            #else
            // iOS
            MCalendarView(
                selectedDate: $viewModel.selectedDate,
                selectedRange: .constant(nil)
            ) { config in
                config
                    .dayView { date, isCurrentMonth, selectedDate, selectedRange in
                        UBDayView(
                            date: date,
                            isCurrentMonth: isCurrentMonth,
                            selectedDate: selectedDate,
                            selectedRange: selectedRange,
                            summary: viewModel.summary(for: date),
                            selectedOverride: viewModel.selectedDate
                        )
                    }
                    .firstWeekday(.sunday)
                    .monthLabel(UBMonthLabel.init)
                    .startMonth(start)
                    .endMonth(end)
                    .scrollTo(date: calendarScrollDate)
            }
            .transaction { t in
                t.animation = nil
                t.disablesAnimations = true
            }
            .animation(nil, value: viewModel.selectedDate)
            .animation(nil, value: calendarScrollDate)
            .accessibilityIdentifier("IncomeCalendar")
#if os(iOS)
            .frame(maxHeight: .infinity)
#endif
            #endif
        }
        .frame(maxWidth: .infinity)
#if os(iOS)
        .frame(minHeight: calendarCardMinimumHeight, alignment: .top)
#endif
        .layoutPriority(1)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .fill(themeManager.selectedTheme.secondaryBackground)
        )
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
    /// Displays the selected date and a scrollable list of income entries for that day.
    /// Entries keep the unified swipe actions while the lightweight stack scrolls when tall.
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
                // MARK: Scrollable Stack with Unified Swipe Actions
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(entries.enumerated()), id: \.element.objectID) { index, income in
                            IncomeRow(
                                income: income,
                                onEdit: { beginEditingIncome(income) },
                                onDelete: { handleDeleteRequest(income) }
                            )
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)

                            if index < entries.count - 1 {
                                Divider()
                                    .padding(.leading, 12)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .ub_hideScrollIndicators()
                .frame(maxWidth: .infinity)
                .frame(minHeight: 50, maxHeight: 120)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .fill(themeManager.selectedTheme.secondaryBackground)
                .shadow(radius: 1, y: 1)
        )
        .alert("Delete Income?", isPresented: $showDeleteAlert, presenting: incomeToDelete) { income in
            Button("Delete", role: .destructive) {
                viewModel.delete(income: income, scope: .all)
                incomeToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                incomeToDelete = nil
            }
        } message: { _ in
            Text("This will remove the income entry.")
        }
        .confirmationDialog("Delete Recurring Income", isPresented: $showDeleteOptions, presenting: incomeToDelete) { income in
            Button("This Instance Only", role: .destructive) {
                viewModel.delete(income: income, scope: .instance)
            }
            Button("This and Future Instances", role: .destructive) {
                viewModel.delete(income: income, scope: .future)
            }
            Button("All Instances", role: .destructive) {
                viewModel.delete(income: income, scope: .all)
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Calendar Navigation Helpers
    /// Updates the selected date and scroll target for the calendar.
    private func navigate(to date: Date) {
        let target = normalize(date)
        // Update without animation to prevent visible jumps
        withTransaction(Transaction(animation: nil)) {
            viewModel.selectedDate = target
            calendarScrollDate = target
        }
        // Reset the scroll target on the next run loop cycle without animation
        DispatchQueue.main.async {
            withTransaction(Transaction(animation: nil)) {
                calendarScrollDate = nil
            }
        }
    }
    /// Normalizes a date to noon so the calendar highlights the correct day.
    private func normalize(_ date: Date) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        comps.hour = 12
        comps.minute = 0
        comps.second = 0
        return Calendar.current.date(from: comps) ?? date
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

    /// Computes the start and end of the week containing `date` using a Sunday-based calendar.
    private func weekBounds(for date: Date) -> (start: Date, end: Date) {
        let cal = sundayFirstCalendar
        guard let start = cal.dateInterval(of: .weekOfYear, for: date)?.start,
              let end = cal.date(byAdding: .day, value: 6, to: start) else {
            return (date, date)
        }
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
    private func handleDeleteRequest(_ income: Income) {
        incomeToDelete = income
        if income.parentID != nil || !(income.recurrence ?? "").isEmpty {
            showDeleteOptions = true
        } else if confirmBeforeDelete {
            showDeleteAlert = true
        } else {
            viewModel.delete(income: income, scope: .all)
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

    // MARK: Body
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(income.source ?? "—")
                        .font(.headline)
                    if let rec = income.recurrence, !rec.isEmpty, income.parentID == nil {
                        Text("Series Start")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(Color.secondary.opacity(0.1))
                            )
                    }
                }
                Text(currencyString(for: income.amount))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 6)
        // Consistent: slow drag reveals Edit + Delete; full swipe commits Delete on iOS/iPadOS.
        .unifiedSwipeActions(
            UnifiedSwipeConfig(allowsFullSwipeToDelete: false),
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

