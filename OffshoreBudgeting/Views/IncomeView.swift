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

    /// Ensures the calendar makes fuller use of vertical space on compact devices and adapts for Catalyst.
    private var headerBaselineHeight: CGFloat {
#if os(iOS)
    #if targetEnvironment(macCatalyst)
        return 84
    #else
        return 92
    #endif
#else
        return 92
#endif
    }

    private func isCompactHeightScenario(using proxy: RootTabPageProxy?) -> Bool {
#if os(iOS)
        if verticalSizeClass == .compact { return true }
#endif
        if let proxy, proxy.layoutContext.isLandscape { return true }
        return false
    }

    private func calendarCardMinimumHeight(using proxy: RootTabPageProxy?) -> CGFloat {
        isCompactHeightScenario(using: proxy) ? 260 : 300
    }

    private func selectedDayCardMinimumHeight(using proxy: RootTabPageProxy?) -> CGFloat {
        isCompactHeightScenario(using: proxy) ? 280 : 320
    }

    private func weeklySummaryCardMinimumHeight(using proxy: RootTabPageProxy?) -> CGFloat {
        isCompactHeightScenario(using: proxy) ? 120 : 140
    }

    private func calendarContentHeight(using proxy: RootTabPageProxy?) -> CGFloat {
#if os(iOS)
        if horizontalSizeClass == .regular { return 440 }
        if verticalSizeClass == .compact { return 300 }
#endif
        if proxy?.layoutContext.isLandscape == true { return 280 }
        return 320
    }



    private enum CalendarSectionMetrics {
        static let navigationRowHeight: CGFloat = max(
            TranslucentButtonStyle.Metrics.calendarNavigationIcon.height ?? 0,
            TranslucentButtonStyle.Metrics.calendarNavigationLabel.height ?? 0
        )
        static let headerSpacing: CGFloat = 8
    }

    private let calendarSectionContentPadding: CGFloat = 10

    private func minimumCardHeights(using proxy: RootTabPageProxy?) -> IncomeCardHeights {
        IncomeCardHeights(
            calendar: calendarCardMinimumHeight(using: proxy),
            selected: selectedDayCardMinimumHeight(using: proxy),
            summary: weeklySummaryCardMinimumHeight(using: proxy)
        )
    }

    private let landscapeLayoutMinimumWidth: CGFloat = 780

    private struct IncomeCardHeights {
        let calendar: CGFloat
        let selected: CGFloat
        let summary: CGFloat
    }

    private func beginAddingIncome(for date: Date? = nil) {
        let baseDate = date ?? viewModel.selectedDate ?? Date()
        addIncomeInitialDate = AddIncomeSheetDate(value: baseDate)
    }

    private var addIncomeButton: some View {
        Button(action: { beginAddingIncome() }) {
            Image(systemName: "plus")
        }
        .accessibilityLabel("Add Income")
        .accessibilityIdentifier("add_income_button")
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
        RootTabPageScaffold(spacing: DS.Spacing.s) {
            EmptyView()
        } content: { proxy in
            content(using: proxy)
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
        .navigationTitle("Income")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                addIncomeButton
            }
        }
    }

    @ViewBuilder
    private func content(using proxy: RootTabPageProxy) -> some View {
        let availableHeight = max(proxy.availableHeightBelowHeader, 0)

        if proxy.layoutContext.isLandscape,
           proxy.layoutContext.containerSize.width >= landscapeLayoutMinimumWidth {
            landscapeLayout(using: proxy, availableHeight: availableHeight)
        } else if #available(iOS 16.0, macCatalyst 16.0, *) {
            ViewThatFits(in: .vertical) {
                nonScrollingLayout(using: proxy, availableHeight: availableHeight)
                scrollingLayout(using: proxy)
            }
        } else {
            scrollingLayout(using: proxy)
        }
    }

    private func landscapeLayout(using proxy: RootTabPageProxy, availableHeight: CGFloat) -> some View {
        let minimums = minimumCardHeights(using: proxy)
        let gutter = proxy.compactAwareTabBarGutter
        let horizontalInset = proxy.resolvedSymmetricHorizontalInset(capabilities: capabilities)
        let heights = adaptiveCardHeights(
            using: proxy,
            availableHeight: availableHeight,
            tabBarGutter: gutter,
            minimums: minimums
        )
        let selectedHeight = max(heights.selected, minimums.selected)
        let summaryHeight = max(heights.summary, minimums.summary)
        let rightColumnHeight = selectedHeight + DS.Spacing.m + summaryHeight
        let navigationHeaderHeight = CalendarSectionMetrics.navigationRowHeight + CalendarSectionMetrics.headerSpacing
        let calendarCardHeight = max(
            rightColumnHeight - (calendarSectionContentPadding * 2) - navigationHeaderHeight,
            minimums.calendar
        )
        let horizontalPadding = horizontalInset * 2
        let columnSpacing = DS.Spacing.l
        let availableWidth = max(proxy.layoutContext.containerSize.width - horizontalPadding - columnSpacing, 0)
        let calendarFraction: CGFloat = 0.58
        let calendarWidth = max(availableWidth * calendarFraction, 0)

        return HStack(alignment: .top, spacing: columnSpacing) {
            calendarSection(using: proxy, cardHeight: calendarCardHeight)
                .frame(width: calendarWidth, alignment: .top)

            VStack(spacing: DS.Spacing.m) {
                selectedDaySection(minHeight: minimums.selected)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .frame(height: selectedHeight, alignment: .top)

                weeklySummaryBar(minHeight: minimums.summary)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .frame(height: summaryHeight, alignment: .top)
            }
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .rootTabContentPadding(
            proxy,
            horizontal: horizontalInset,
            extraTop: DS.Spacing.s,
            includeSafeArea: false,
            tabBarGutter: gutter
        )
        .frame(
            minHeight: minimumNonScrollingHeight(using: proxy, tabBarGutter: gutter),
            alignment: .top
        )
    }

    private func nonScrollingLayout(using proxy: RootTabPageProxy, availableHeight: CGFloat) -> some View {
        let minimums = minimumCardHeights(using: proxy)
        let gutter = proxy.compactAwareTabBarGutter
        let horizontalInset = proxy.resolvedSymmetricHorizontalInset(capabilities: capabilities)
        let heights = adaptiveCardHeights(
            using: proxy,
            availableHeight: availableHeight,
            tabBarGutter: gutter,
            minimums: minimums
        )

        return VStack(spacing: DS.Spacing.m) {
            calendarSection(using: proxy, cardHeight: heights.calendar)

            selectedDaySection(minHeight: minimums.selected)
                .frame(maxHeight: .infinity, alignment: .top)
                .frame(height: max(heights.selected, minimums.selected), alignment: .top)

            weeklySummaryBar(minHeight: minimums.summary)
                .frame(height: max(heights.summary, minimums.summary), alignment: .top)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .rootTabContentPadding(
            proxy,
            horizontal: horizontalInset,
            extraTop: DS.Spacing.s,
            includeSafeArea: false,
            tabBarGutter: gutter
        )
        .frame(
            minHeight: minimumNonScrollingHeight(using: proxy, tabBarGutter: gutter),
            alignment: .top
        )
    }

    private func scrollingLayout(using proxy: RootTabPageProxy) -> some View {
        let minimums = minimumCardHeights(using: proxy)
        let gutter = proxy.compactAwareTabBarGutter
        let horizontalInset = proxy.resolvedSymmetricHorizontalInset(capabilities: capabilities)

        return ScrollView(showsIndicators: false) {
            VStack(spacing: DS.Spacing.m) {
                calendarSection(using: proxy)

                selectedDaySection(minHeight: minimums.selected)

                weeklySummaryBar(minHeight: minimums.summary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .rootTabContentPadding(
                proxy,
                horizontal: horizontalInset,
                extraTop: DS.Spacing.s,
                includeSafeArea: false,
                tabBarGutter: gutter
            )
        }
        // Removed extra bottom inset; RootTabPageScaffold + rootTabContentPadding
        // control any desired gutter above the tab bar.
    }

    private func adaptiveCardHeights(
        using proxy: RootTabPageProxy,
        availableHeight: CGFloat,
        tabBarGutter: RootTabPageProxy.TabBarGutter,
        minimums providedMinimums: IncomeCardHeights? = nil
    ) -> IncomeCardHeights {
        let cardSpacing = DS.Spacing.m * 2
        let minimums = providedMinimums ?? minimumCardHeights(using: proxy)
        let baseTotal = minimums.calendar + minimums.selected + minimums.summary
        let bottomPadding = proxy.tabBarGutterSpacing(tabBarGutter)
        let adjustedHeight = max(availableHeight - bottomPadding, baseTotal + cardSpacing)
        let extra = max(adjustedHeight - baseTotal - cardSpacing, 0)

        let calendar = minimums.calendar + (extra * 0.22)
        let summary = minimums.summary + (extra * 0.08)
        let selected = adjustedHeight - calendar - summary - cardSpacing

        return IncomeCardHeights(
            calendar: max(calendar, minimums.calendar),
            selected: max(selected, minimums.selected),
            summary: max(summary, minimums.summary)
        )
    }

    private func minimumNonScrollingHeight(
        using proxy: RootTabPageProxy,
        tabBarGutter: RootTabPageProxy.TabBarGutter
    ) -> CGFloat {
        let minimums = minimumCardHeights(using: proxy)
        let baseCards = minimums.calendar + minimums.selected + minimums.summary
        let verticalSpacing = proxy.spacing + (DS.Spacing.m * 2)
        let fallbackHeader = headerBaselineHeight + proxy.effectiveSafeAreaInsets.top
        let headerHeight = proxy.headerHeight > 0 ? proxy.headerHeight : fallbackHeader
        return headerHeight + verticalSpacing + baseCards + proxy.tabBarGutterSpacing(tabBarGutter)
    }

    // MARK: - Calendar Section
    /// Wraps the `MCalendarView` in a card and applies a stark black & white appearance.
    /// In light mode the background is white; in dark mode it is black; selection styling handled by the calendar views.
    @ViewBuilder
    private func calendarSection(using proxy: RootTabPageProxy, cardHeight: CGFloat? = nil) -> some View {
        let resolvedHeight = max(
            cardHeight ?? calendarContentHeight(using: proxy),
            calendarCardMinimumHeight(using: proxy)
        )
        let today = Date()
        let cal = sundayFirstCalendar
        let start = cal.date(byAdding: .year, value: -5, to: today)!
        let end = cal.date(byAdding: .year, value: 5, to: today)!
        VStack(spacing: CalendarSectionMetrics.headerSpacing) {
            HStack(spacing: DS.Spacing.s) {
                Button("<<") { goToPreviousMonth() }
                    .accessibilityLabel("Previous Month")
                    .incomeCalendarGlassButtonStyle(role: .icon)

                Button("<") { goToPreviousDay() }
                    .accessibilityLabel("Previous Day")
                    .incomeCalendarGlassButtonStyle(role: .icon)

                Button("Today") { goToToday() }
                    .accessibilityLabel("Jump to Today")
                    .incomeCalendarGlassButtonStyle(role: .label)

                Button(">") { goToNextDay() }
                    .accessibilityLabel("Next Day")
                    .incomeCalendarGlassButtonStyle(role: .icon)

                Button(">>") { goToNextMonth() }
                    .accessibilityLabel("Next Month")
                    .incomeCalendarGlassButtonStyle(role: .icon)
            }
            .frame(minHeight: max(CalendarSectionMetrics.navigationRowHeight, 44))
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
            .frame(height: resolvedHeight, alignment: .top)
        }
        .frame(maxWidth: .infinity)
        .layoutPriority(1)
        .padding(calendarSectionContentPadding)
        .incomeSectionContainerStyle(theme: themeManager.selectedTheme, capabilities: capabilities)
    }

    // MARK: - Weekly Summary Bar
    /// Small bar that totals the week containing the selected date.
    @ViewBuilder
    private func weeklySummaryBar(minHeight: CGFloat) -> some View {
        let (start, end) = weekBounds(for: viewModel.selectedDate ?? Date())

        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: DS.Spacing.s) {
                    Text("Week Total Income")
                        .font(.headline)

                    incomeTotalsStack(
                        planned: viewModel.plannedTotalForSelectedWeek,
                        actual: viewModel.actualTotalForSelectedWeek,
                        leadingAlignment: true
                    )
                }

                Spacer(minLength: 0)
            }

            Text("\(formattedDate(start)) – \(formattedDate(end))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(DS.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: minHeight, alignment: .top)
        .incomeSectionContainerStyle(theme: themeManager.selectedTheme, capabilities: capabilities)
    }

    // MARK: - Selected Day Section (WITH swipe to delete & edit)
    /// Displays the selected date and a list of income entries for that day.
    /// The list supports native swipe actions; it also scrolls when tall; pill styling preserved.
    @ViewBuilder
    private func selectedDaySection(minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            let date = viewModel.selectedDate ?? Date()
            let entries: [Income] = viewModel.incomesForDay   // Explicit type trims solver work

            // MARK: Section Title — Selected Day
            selectedDayHeader(for: date)

            selectedDayContent(for: entries, date: date)
        }
        .padding(DS.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: minHeight, alignment: .top)
        .incomeSectionContainerStyle(theme: themeManager.selectedTheme, capabilities: capabilities)
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
        VStack(alignment: .leading, spacing: 4) {
            Text("Selected Day Income")
                .font(.headline)
            Text(DateFormatter.localizedString(from: date, dateStyle: .full, timeStyle: .none))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func selectedDayContent(for entries: [Income], date: Date) -> some View {
        if entries.isEmpty {
            selectedDayEmptyState(for: date)
        } else {
            incomeList(for: entries)
                .frame(maxHeight: .infinity)
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
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                .listRowBackground(Color.clear)
            }
        }
        .ub_listStyleLiquidAware()
        .ub_hideScrollIndicators()
    }

    @ViewBuilder
    private func incomeTotalsStack(planned: Double, actual: Double, leadingAlignment: Bool) -> some View {
        VStack(alignment: leadingAlignment ? .leading : .trailing, spacing: DS.Spacing.xs) {
            incomeTotalsRow(
                label: "Planned",
                amount: planned,
                tint: DS.Colors.plannedIncome,
                leadingAlignment: leadingAlignment
            )
            incomeTotalsRow(
                label: "Actual",
                amount: actual,
                tint: DS.Colors.actualIncome,
                leadingAlignment: leadingAlignment
            )
        }
    }

    private func incomeTotalsRow(label: String, amount: Double, tint: Color, leadingAlignment: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.s) {
            if !leadingAlignment {
                Spacer(minLength: 0)
            }

            Text("\(label):")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(currencyString(for: amount))
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .layoutPriority(1)

            if leadingAlignment {
                Spacer(minLength: 0)
            }
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
        return nf.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
    }
}

// MARK: - Section Styling Helpers
private extension View {
    func incomeCalendarGlassButtonStyle(role: CalendarNavigationButtonStyle.Role) -> some View {
        modifier(IncomeCalendarGlassButtonModifier(role: role))
    }

    @ViewBuilder
    func incomeSectionContainerStyle(theme: AppTheme, capabilities: PlatformCapabilities) -> some View {
        self
            .background(
                theme.secondaryBackground,
                in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
            )
            .compositingGroup()
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
            .shadow(radius: 1, y: 1)
    }
}

// MARK: - Availability Helpers
private extension View {
    /// Hides list background on supported OS versions; no-ops on older targets.
    @ViewBuilder
    func applyIfAvailableScrollContentBackgroundHidden() -> some View {
        if #available(iOS 16.0, macCatalyst 16.0, *) {
            scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}

// MARK: - Calendar Navigation Styling
private struct IncomeCalendarGlassButtonModifier: ViewModifier {
    @Environment(\.platformCapabilities) private var capabilities
    @EnvironmentObject private var themeManager: ThemeManager

    private let cornerRadius: CGFloat = 17
    private let role: CalendarNavigationButtonStyle.Role

    init(role: CalendarNavigationButtonStyle.Role) {
        self.role = role
    }

    func body(content: Content) -> some View {
        if capabilities.supportsOS26Translucency, #available(iOS 26.0, macCatalyst 26.0, *) {
            content
                .buttonStyle(.glass)
                .tint(themeManager.selectedTheme.resolvedTint)
                .buttonBorderShape(.roundedRectangle(radius: cornerRadius))
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            content
                .buttonStyle(CalendarNavigationButtonStyle(role: role))
                .buttonBorderShape(.roundedRectangle(radius: cornerRadius))
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}
