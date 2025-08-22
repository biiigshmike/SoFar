//
//  IncomeCalendarPalette.swift
//  SoFar
//
//  Shared calendar components for MijickCalendarView.
//  Provides custom month and day views plus macOS-specific weekday styling.
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

// MARK: - Day cell with income summaries
/// Displays the day number plus optional planned/actual income amounts.
struct UBDayView: DayView {
    // Required attributes (from DayView)
    let date: Date
    let isCurrentMonth: Bool
    var selectedDate: Binding<Date?>?
    var selectedRange: Binding<MDateRange?>?
    let summary: (planned: Double, actual: Double)?

    @Environment(\.colorScheme) private var scheme

    func createContent() -> AnyView {
        AnyView(
            VStack(spacing: 2) {
                ZStack {
                    createSelectionView()
                    createRangeSelectionView()
                    createDayLabel()
                }
                let planned = summary?.planned ?? 0
                let actual = summary?.actual ?? 0
                VStack(spacing: 1) {
                    if planned > 0 && actual > 0 {
                        Text(currencyString(planned))
                            .font(.system(size: 8, weight: .regular))
                            .foregroundColor(DS.Colors.plannedIncome)
                        Text(currencyString(actual))
                            .font(.system(size: 8, weight: .regular))
                            .foregroundColor(DS.Colors.actualIncome)
                    } else if planned > 0 {
                        Text(currencyString(planned))
                            .font(.system(size: 8, weight: .regular))
                            .foregroundColor(DS.Colors.plannedIncome)
                    } else if actual > 0 {
                        Text(currencyString(actual))
                            .font(.system(size: 8, weight: .regular))
                            .foregroundColor(DS.Colors.actualIncome)
                    }
                }
            }
        )
    }

    // Text: 16pt semibold; black in light, white in dark; flips on selection
    func createDayLabel() -> AnyView {
        let base = scheme == .dark ? Color.white : Color.black
        let selected = scheme == .dark ? Color.black : Color.white
        let color = isSelected() ? selected : base
        return AnyView(
            Text(getStringFromDay(format: "d"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
                .opacity(isCurrentMonth ? 1 : 0.28)
        )
    }

    // Selection circle: white in dark mode; black in light mode
    func createSelectionView() -> AnyView {
        let fill = scheme == .dark ? Color.white : Color.black
        return AnyView(
            Circle()
                .fill(fill)
                .frame(width: 32, height: 32)
                .opacity(isSelected() ? 1 : 0)
        )
    }

    // We do not use range selection; return empty.
    func createRangeSelectionView() -> AnyView { AnyView(EmptyView()) }

    private func currencyString(_ amount: Double) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.maximumFractionDigits = 0
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

