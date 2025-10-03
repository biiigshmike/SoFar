//
//  IncomeCalendarPalette.swift
//  SoFar
//
//  Shared calendar components for MijickCalendarView.
//  Provides custom month and day views for the shared calendar presentation.
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
    /// External date used to force selection updates when navigation buttons are tapped.
    let selectedOverride: Date?

    @Environment(\.colorScheme) private var scheme

    func createContent() -> AnyView {
        let planned = summary?.planned ?? 0
        let actual = summary?.actual ?? 0
        let hasEvents = (planned + actual) > 0

        var content: some View {
            VStack(spacing: 2) {
                ZStack {
                    createSelectionView()
                    createRangeSelectionView()
                    createDayLabel()
                }
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
                // Reserve space so day numbers align even when income is absent
                .frame(height: 20, alignment: .top)
            }
            // Fill the available cell space and pin content to the top
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }

        if hasEvents {
            return AnyView(
                content
                    .accessibilityIdentifier("income_day_has_events_\(ymdString(date))")
            )
        } else {
            return AnyView(content)
        }
    }

    // Text: 16pt semibold; black in light, white in dark; flips on selection
    func createDayLabel() -> AnyView {
        let base = scheme == .dark ? Color.white : Color.black
        let selected = scheme == .dark ? Color.black : Color.white
        let color = isSelectedDay() ? selected : base
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
                .opacity(isSelectedDay() ? 1 : 0)
        )
    }

    // We do not use range selection; return empty.
    func createRangeSelectionView() -> AnyView { AnyView(EmptyView()) }

    private func isSelectedDay() -> Bool {
        if let override = selectedOverride {
            return Calendar.current.isDate(override, inSameDayAs: date)
        }
        guard let selected = selectedDate?.wrappedValue else { return false }
        return Calendar.current.isDate(selected, inSameDayAs: date)
    }

    private func currencyString(_ amount: Double) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.maximumFractionDigits = 0
        return nf.string(from: amount as NSNumber) ?? ""
    }

    private func ymdString(_ d: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }
}

