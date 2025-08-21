//
//  IncomeCalendarPalette_v2.swift
//  SoFar
//
//  Custom views for MijickCalendarView.
//  Provides a shared MonthLabel and macOS-specific day/weekday styling.
//

import SwiftUI
import MijickCalendarView

// MARK: - Month title (e.g., "August 2025")
struct UBMonthLabel: MonthLabel {
    // Required attribute (from MonthLabel)
    let month: Date

    @Environment(\.colorScheme) private var scheme

    func createContent() -> AnyView {
        let base = scheme == .dark ? Color.white : Color.black
        return AnyView(
            Text(getString(format: "MMMM y"))
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(base)
        )
    }
}

// MARK: - Day cell with optional income amounts
struct UBDayView: DayView {
    // Required attributes (from DayView)
    let date: Date
    let isCurrentMonth: Bool
    var selectedDate: Binding<Date?>?
    var selectedRange: Binding<MDateRange?>?

    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var eventStore: IncomeCalendarEventStore

    // Text + income amounts stacked vertically
    func createDayLabel() -> AnyView {
        let base = scheme == .dark ? Color.white : Color.black
        let selected = scheme == .dark ? Color.black : Color.white
        let color = isSelected() ? selected : base

        let day = Calendar.current.startOfDay(for: date)
        let events = eventStore.eventsByDay[day] ?? []
        let planned = events.filter { $0.isPlanned }.reduce(0) { $0 + $1.amount }
        let actual  = events.filter { !$0.isPlanned }.reduce(0) { $0 + $1.amount }

        return AnyView(
            VStack(spacing: 1) {
                Text(getStringFromDay(format: "d"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
                    .opacity(isCurrentMonth ? 1 : 0.28)
                if planned > 0 {
                    Text(currencyString(planned))
                        .font(.system(size: 9))
                        .foregroundColor(DS.Colors.plannedIncome)
                }
                if actual > 0 {
                    Text(currencyString(actual))
                        .font(.system(size: 9))
                        .foregroundColor(DS.Colors.actualIncome)
                }
            }
        )
    }

    // Selection circle tinted with theme accent
    func createSelectionView() -> AnyView {
        if isSelected() {
            return AnyView(
                Circle()
                    .fill(themeManager.selectedTheme.accent)
                    .frame(width: 32, height: 32)
            )
        } else {
            return AnyView(EmptyView())
        }
    }

    // We do not use range selection; return empty.
    func createRangeSelectionView() -> AnyView { AnyView(EmptyView()) }

    // MARK: Helpers
    private func currencyString(_ amount: Double) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.locale = .current
        return nf.string(from: amount as NSNumber) ?? ""
    }
}

#if os(macOS)

// MARK: - Weekday label (M T W T F S S)
struct UBWeekdayLabel: WeekdayLabel {
    // Required attribute (from WeekdayLabel)
    let weekday: MWeekday

    @Environment(\.colorScheme) private var scheme

    func createContent() -> AnyView {
        let base = scheme == .dark ? Color.white : Color.black
        return AnyView(
            Text(getString(with: .veryShort))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(base.opacity(0.45))
        )
    }
}

// MARK: - Weekdays row
struct UBWeekdaysView: WeekdaysView {
    func createContent() -> AnyView { AnyView(createWeekdaysView()) }
    func createWeekdayLabel(_ weekday: MWeekday) -> AnyWeekdayLabel {
        UBWeekdayLabel(weekday: weekday).erased()
    }
}

#endif
