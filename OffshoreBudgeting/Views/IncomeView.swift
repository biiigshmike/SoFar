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
    @Environment(\.ub_safeAreaInsets) private var safeAreaInsets
    @Environment(\.platformCapabilities) private var capabilities
    // MARK: View Model
    /// External owner should initialize and provide the view model; it manages selection and CRUD.
    @StateObject var viewModel = IncomeScreenViewModel()
    @AppStorage(AppSettingsKeys.calendarHorizontal.rawValue) private var calendarHorizontal: Bool = true
    @AppStorage(AppSettingsKeys.confirmBeforeDelete.rawValue) private var confirmBeforeDelete: Bool = true
    @State private var incomeToDelete: Income? = nil
    @State private var showDeleteAlert: Bool = false
    @State private var showDeleteOptions: Bool = false
    @State private var weeklySummaryIntrinsicHeight: CGFloat = 0
    @State private var selectedDayHeaderHeight: CGFloat = 0
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
#endif

#if os(iOS)
    /// Ensures the calendar makes fuller use of vertical space on compact devices like iPhone.
    private let calendarCardMinimumHeight: CGFloat = 340
    private var calendarContentHeight: CGFloat {
        if horizontalSizeClass == .regular { return 480 }
        if verticalSizeClass == .compact { return 340 }
        return 360
    }
#else
    private let calendarContentHeight: CGFloat = 360
#endif

    private var bottomPadding: CGFloat {
#if os(iOS)
        let inset = safeAreaInsets.bottom
        return inset > 0 ? inset : DS.Spacing.m
#else
        return DS.Spacing.m
#endif
    }

    /// Minimum padding applied directly to the scroll view content so that the
    /// cards never butt up against the edge while we wait for safe area values
    /// to resolve.
    private var scrollViewContentBottomPadding: CGFloat { DS.Spacing.m }

    /// Additional spacing inserted via a safe-area inset once we know the
    /// device's actual bottom inset.  This keeps the initial layout stable so
    /// the user doesn't need to scroll after the safe area updates.
    private var bottomInsetCompensation: CGFloat {
        max(bottomPadding - scrollViewContentBottomPadding, 0)
    }

    private var summaryFallbackHeight: CGFloat {
#if os(iOS)
        if horizontalSizeClass == .regular { return 280 }
        if verticalSizeClass == .compact { return 220 }
        return 240
#else
        return 240
#endif
    }

    private var minimumSelectedDayContentHeight: CGFloat {
#if os(iOS)
        if verticalSizeClass == .compact { return 90 }
        return 120
#else
        return 140
#endif
    }

    private var targetSummaryCardHeight: CGFloat {
        let fallback = summaryFallbackHeight
        let weeklyHeight = weeklySummaryIntrinsicHeight
        let headerAllowance: CGFloat = selectedDayHeaderHeight > 0
            ? selectedDayHeaderHeight + minimumSelectedDayContentHeight
            : 0

        let intrinsic = max(weeklyHeight, headerAllowance)
        if intrinsic <= 0 { return fallback }
        return max(fallback, intrinsic)
    }

    private func beginAddingIncome(for date: Date? = nil) {
        let baseDate = date ?? viewModel.selectedDate ?? Date()
        addIncomeInitialDate = AddIncomeSheetDate(value: baseDate)
    }

    private var addIncomeButton: some View {
        RootHeaderIconActionButton(
            systemImage: "plus",
            accessibilityLabel: "Add Income",
            accessibilityIdentifier: "add_income_button"
        ) {
            beginAddingIncome()
        }
    }

    // MARK: Calendar
    /// Calendar configured to begin weeks on Sunday.
    private var sundayFirstCalendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 1 // 1 = Sunday
        return calendar
    }

    // MARK: Body
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: DS.Spacing.l) {
                RootViewTopPlanes(title: "Income") {
                    addIncomeButton
                }

                VStack(spacing: 8) {
                    // Calendar section in a padded card
                    calendarSection

                    // Weekly summary and selected day entries displayed side-by-side
                    summarySplit
                }
                .padding(.horizontal, DS.Spacing.l)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, scrollViewContentBottomPadding)
        }
        .ub_captureSafeAreaInsets()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear
                .frame(height: bottomInsetCompensation)
                .allowsHitTesting(false)
        }
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
            .frame(height: calendarContentHeight, alignment: .top)
            // MARK: Double-click calendar to add income (macOS)
            .simultaneousGesture(
                TapGesture(count: 2).onEnded {
                    beginAddingIncome(for: viewModel.selectedDate ?? today)
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
            .frame(height: calendarContentHeight, alignment: .top)
#endif
        }
        .frame(maxWidth: .infinity)
#if os(iOS)
        .frame(minHeight: calendarCardMinimumHeight, alignment: .top)
#endif
        .layoutPriority(1)
        .padding(10)
        .background(
            themeManager.selectedTheme.secondaryBackground,
            in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
        )
        .compositingGroup()
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
    }

    // MARK: - Summary Layout
    @ViewBuilder
    private var summarySplit: some View {
        let cardHeight = targetSummaryCardHeight

        HStack(alignment: .top, spacing: DS.Spacing.m) {
            weeklySummaryBar
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .frame(minHeight: cardHeight, alignment: .top)

            selectedDaySection
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .frame(minHeight: cardHeight, alignment: .top)
        }
        .onPreferenceChange(WeeklySummaryHeightPreferenceKey.self) { height in
            guard height > 0 else { return }
            if weeklySummaryIntrinsicHeight != height {
                weeklySummaryIntrinsicHeight = height
            }
        }
        .onPreferenceChange(SelectedDayHeaderHeightPreferenceKey.self) { height in
            guard height > 0 else { return }
            if selectedDayHeaderHeight != height {
                selectedDayHeaderHeight = height
            }
        }
    }

    // MARK: - Weekly Summary Bar
    /// Small bar that totals the week containing the selected date.
    @ViewBuilder
    private var weeklySummaryBar: some View {
        let (start, end) = weekBounds(for: viewModel.selectedDate ?? Date())

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "calendar")
                    .imageScale(.large)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Week Total Income")
                        .font(.headline)
                    Text(currencyString(for: viewModel.totalForSelectedWeek))
                        .font(.title3)
                        .fontWeight(.semibold)
                }

                Spacer(minLength: 0)
            }

            Text("\(formattedDate(start)) – \(formattedDate(end))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(
            themeManager.selectedTheme.secondaryBackground,
            in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
        )
        .compositingGroup()
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .shadow(radius: 1, y: 1)
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(
                        key: WeeklySummaryHeightPreferenceKey.self,
                        value: proxy.size.height
                    )
            }
        )
    }

    // MARK: - Selected Day Section (WITH swipe to delete & edit)
    /// Displays the selected date and a list of income entries for that day.
    /// The list supports native swipe actions; it also scrolls when tall; pill styling preserved.
    @ViewBuilder
    private var selectedDaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            let date = viewModel.selectedDate ?? Date()
            let entries: [Income] = viewModel.incomesForDay   // Explicit type trims solver work

            // MARK: Section Title — Selected Day
            selectedDayHeader(for: date)

            selectedDayContent(for: entries, date: date)
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            themeManager.selectedTheme.secondaryBackground,
            in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
        )
        .compositingGroup()
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .shadow(radius: 1, y: 1)
        .layoutPriority(2)
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

    private func selectedDayHeader(for date: Date) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Selected Day Income")
                    .font(.headline)
                Text(DateFormatter.localizedString(from: date, dateStyle: .full, timeStyle: .none))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(currencyString(for: viewModel.totalForSelectedDate))
                .font(.title3)
                .fontWeight(.semibold)
        }
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(
                        key: SelectedDayHeaderHeightPreferenceKey.self,
                        value: proxy.size.height + DS.Spacing.m
                    )
            }
        )
    }

    @ViewBuilder
    private func selectedDayContent(for entries: [Income], date: Date) -> some View {
        if entries.isEmpty {
            selectedDayEmptyState(for: date)
            Spacer(minLength: 0)
        } else {
            incomeList(for: entries)
        }
    }

    @ViewBuilder
    private func selectedDayEmptyState(for date: Date) -> some View {
        Text("No income for \(formattedDate(date)).")
            .foregroundStyle(.secondary)
            .font(.subheadline)
            .padding(.vertical, 4)
    }

    private func incomeList(for entries: [Income]) -> some View {
        List {
            ForEach(entries, id: \.objectID) { income in
                IncomeRow(
                    income: income,
                    onEdit: { beginEditingIncome(income) },
                    onDelete: { handleDeleteRequest(income) }
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .ub_hideScrollIndicators()
        .applyIfAvailableScrollContentBackgroundHidden()
        .frame(maxHeight: .infinity, alignment: .top)
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

// MARK: - Height Preference Keys
private struct WeeklySummaryHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct SelectedDayHeaderHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

