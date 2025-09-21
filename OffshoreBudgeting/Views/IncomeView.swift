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
    @State private var calendarScrollDate: Date? = Date()

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
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
#endif

#if os(iOS)
    /// Ensures the calendar makes fuller use of vertical space on compact devices like iPhone.
    private let calendarCardMinimumHeight: CGFloat = 380
#endif

    private let addButtonDimension: CGFloat = 44

    private var bottomPadding: CGFloat {
#if os(iOS)
        return safeAreaInsets.bottom + DS.Spacing.xl
#else
        return DS.Spacing.xl
#endif
    }

    private func beginAddingIncome(for date: Date? = nil) {
        let baseDate = date ?? viewModel.selectedDate ?? Date()
        addIncomeInitialDate = AddIncomeSheetDate(value: baseDate)
    }

    @ViewBuilder
    private var addIncomeButton: some View {
        let button = Button { beginAddingIncome() } label: {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .semibold))
                .frame(width: addButtonDimension, height: addButtonDimension)
        }
        .tint(themeManager.selectedTheme.resolvedTint)
        .accessibilityLabel("Add Income")
        .accessibilityIdentifier("add_income_button")

        if #available(iOS 26.0, macOS 15.0, tvOS 18.0, *), capabilities.supportsOS26Translucency {
            button.buttonStyle(.glassProminent)
        } else {
            button.buttonStyle(
                TranslucentButtonStyle(
                    tint: themeManager.selectedTheme.resolvedTint,
                    metrics: .rootActionIcon
                )
            )
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
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                RootViewTopPlanes(title: "Income") {
                    addIncomeButton
                }

                VStack(spacing: 12) {
                    // Calendar section in a padded card
                    calendarSection

                    // Weekly summary bar
                    weeklySummaryBar

                    // Selected day entries
                    selectedDaySection
                }
                .padding(.horizontal, DS.Spacing.l)
                .padding(.bottom, DS.Spacing.m)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, bottomPadding)
        }
        .ub_captureSafeAreaInsets()
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
#if os(iOS)
            .background(CalendarScrollDisabler())
            // Allow the calendar to size itself naturally so the weekly summary
            // and selected-day cards remain visible beneath it. Using
            // `maxHeight: .infinity` caused the card to consume the entire
            // scroll view height on iPhone, pushing the other sections off
            // screen.
            .fixedSize(horizontal: false, vertical: true)
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
            themeManager.selectedTheme.secondaryBackground,
            in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
        )
        .compositingGroup()
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
    }

    // MARK: - Weekly Summary Bar
    /// Small bar that totals the week containing the selected date.
    @ViewBuilder
    private var weeklySummaryBar: some View {
        let date = viewModel.selectedDate ?? Date()
        let (start, end) = weekBounds(for: date)
        let weeklyTotals = viewModel.weeklyTotals(
            containing: date,
            firstWeekday: sundayFirstCalendar.firstWeekday
        )
        let totalAmount = weeklyTotals.planned + weeklyTotals.actual

        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            HStack(alignment: .firstTextBaseline) {
                Text("Week Total Income")
                    .font(.headline)
                Spacer()
                Text(currencyString(for: totalAmount))
                    .font(.headline)
            }

            Text("\(formattedDate(start)) – \(formattedDate(end))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: DS.Spacing.s) {
                summaryPill(title: "Planned", amount: weeklyTotals.planned, tint: DS.Colors.plannedIncome)
                summaryPill(title: "Actual", amount: weeklyTotals.actual, tint: DS.Colors.actualIncome)
                Spacer(minLength: 0)
            }
        }
        .padding(DS.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            themeManager.selectedTheme.secondaryBackground,
            in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
        )
        .compositingGroup()
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .shadow(radius: 1, y: 1)
    }

    // MARK: - Selected Day Section (WITH swipe to delete & edit)
    /// Displays the selected date and a list of income entries for that day.
    /// The list supports native swipe actions; it also scrolls when tall; pill styling preserved.
    @ViewBuilder
    private var selectedDaySection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            let date = viewModel.selectedDate ?? Date()
            let entries: [Income] = viewModel.incomesForDay   // Explicit type trims solver work
            let totals = plannedActualTotals(for: entries)
            let totalAmount = totals.planned + totals.actual

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Selected Day Income")
                        .font(.headline)
                    Spacer()
                    Text(currencyString(for: totalAmount))
                        .font(.headline)
                }

                Text(DateFormatter.localizedString(from: date, dateStyle: .full, timeStyle: .none))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !entries.isEmpty {
                HStack(spacing: DS.Spacing.s) {
                    summaryPill(title: "Planned", amount: totals.planned, tint: DS.Colors.plannedIncome)
                    summaryPill(title: "Actual", amount: totals.actual, tint: DS.Colors.actualIncome)
                    Spacer(minLength: 0)
                }
            }

            selectedDayContent(for: entries, date: date)
        }
        .padding(DS.Spacing.m)
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

    @ViewBuilder
    private func selectedDayContent(for entries: [Income], date: Date) -> some View {
        if entries.isEmpty {
            selectedDayEmptyState(for: date)
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
            .onDelete { indexSet in
                handleDelete(indexSet, in: entries)
            }
        }
        .listStyle(.plain)
        .ub_hideScrollIndicators()
        .applyIfAvailableScrollContentBackgroundHidden()
        .frame(height: dayListHeight(for: entries.count))
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

    /// Determines how tall the daily income list should be so rows have space and longer days can scroll.
    private func dayListHeight(for entryCount: Int) -> CGFloat {
        guard entryCount > 0 else { return 140 }

        let estimatedRowHeight: CGFloat = 64
        let basePadding: CGFloat = 28 // top/bottom padding + separators
        let preferred = CGFloat(entryCount) * estimatedRowHeight + basePadding

#if os(iOS)
        let isRegularWidth = horizontalSizeClass == .regular
        let isCompactVertical = verticalSizeClass == .compact
        let maxHeight: CGFloat = {
            if isRegularWidth { return 420 }
            if isCompactVertical { return 240 }
            return 320
        }()
#else
        let maxHeight: CGFloat = 380
#endif

        let minHeight: CGFloat = 140
        return min(max(preferred, minHeight), maxHeight)
    }

    private func plannedActualTotals(for entries: [Income]) -> (planned: Double, actual: Double) {
        entries.reduce(into: (planned: 0.0, actual: 0.0)) { result, income in
            if income.isPlanned {
                result.planned += income.amount
            } else {
                result.actual += income.amount
            }
        }
    }

    private func summaryPill(title: String, amount: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Text(currencyString(for: amount))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            tint.opacity(0.12),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
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

    private func handleDelete(_ indexSet: IndexSet, in entries: [Income]) {
        let targets = indexSet.compactMap { entries.indices.contains($0) ? entries[$0] : nil }
        targets.forEach { handleDeleteRequest($0) }
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

#if os(iOS)
private struct CalendarScrollDisabler: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        DispatchQueue.main.async { disableScroll(in: view.superview) }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async { disableScroll(in: uiView.superview) }
    }

    private func disableScroll(in root: UIView?) {
        guard let root else { return }

        if let scrollView = root as? UIScrollView {
            scrollView.isScrollEnabled = false
            scrollView.bounces = false
            scrollView.alwaysBounceVertical = false
        }

        for subview in root.subviews {
            disableScroll(in: subview)
        }
    }
}
#endif

