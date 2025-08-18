//
//  IncomeCalendarPalette_v2.swift
//  SoFar
//
//  macOS-only custom views for MijickCalendarView using the package protocols.
//  Forces high-contrast black/white styling to match iOS behavior.
//

import SwiftUI
import MijickCalendarView

#if os(macOS)

// MARK: - Day cell (black/white theme)
struct UBDayView: DayView {
    // Required attributes (from DayView) :contentReference[oaicite:4]{index=4}
    let date: Date
    let isCurrentMonth: Bool
    var selectedDate: Binding<Date?>?
    var selectedRange: Binding<MDateRange?>?

    @Environment(\.colorScheme) private var scheme

    // Text: 16pt semibold; black in light, white in dark; flips on selection
    func createDayLabel() -> AnyView {
        let base = scheme == .dark ? Color.white : Color.black
        let selected = scheme == .dark ? Color.black : Color.white
        let color = isSelected() ? selected : base
        return AnyView(
            Text(getStringFromDay(format: "d")) // helper from DayView :contentReference[oaicite:5]{index=5}
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
                .opacity(isCurrentMonth ? 1 : 0.28)
        )
    }

    // Selection circle: white in dark mode; black in light mode
    func createSelectionView() -> AnyView {
        let fill = scheme == .dark ? Color.white : Color.black
        if isSelected() {
            return AnyView(
                Circle()
                    .fill(fill)
                    .frame(width: 32, height: 32)
            )
        } else {
            return AnyView(EmptyView())
        }
    }


    // We do not use range selection; return empty.
    func createRangeSelectionView() -> AnyView { AnyView(EmptyView()) }
    // Default `onSelection()` already sets selectedDate = date. :contentReference[oaicite:7]{index=7}
}

// MARK: - Weekday label (M T W T F S S)
struct UBWeekdayLabel: WeekdayLabel {
    // Required attribute (from WeekdayLabel) :contentReference[oaicite:8]{index=8}
    let weekday: MWeekday

    @Environment(\.colorScheme) private var scheme

    func createContent() -> AnyView {
        let base = scheme == .dark ? Color.white : Color.black
        return AnyView(
            Text(getString(with: .veryShort)) // helper from WeekdayLabel :contentReference[oaicite:9]{index=9}
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(base.opacity(0.45))
        )
    }
}

// MARK: - Weekdays row
struct UBWeekdaysView: WeekdaysView {
    func createContent() -> AnyView { AnyView(createWeekdaysView()) } // provided helper :contentReference[oaicite:10]{index=10}
    func createWeekdayLabel(_ weekday: MWeekday) -> AnyWeekdayLabel {
        UBWeekdayLabel(weekday: weekday).erased()                      // helper from WeekdayLabel :contentReference[oaicite:11]{index=11}
    }
}

#endif

// MARK: - Month title (e.g., "August 2025")
/// Shared month label used across platforms to display "Month Year".
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
