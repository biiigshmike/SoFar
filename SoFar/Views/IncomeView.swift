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
/// Shows a calendar (MijickCalendarView). Tap a date to add income (Planned/Actual, optional recurrence).
/// Below the calendar, displays incomes for the selected day with edit/delete.
/// A weekly summary bar shows total income for the current week.
struct IncomeView: View {
    // MARK: State
    /// Controls the Add Income Sheet presentation.
    @State private var isPresentingAddIncome: Bool = false
    /// Prefill date for AddIncomeFormView; derived from the currently selected calendar date or today.
    @State private var addIncomeInitialDate: Date? = nil
    
    // MARK: Environment
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.managedObjectContext) private var viewContext
    
    // MARK: View Model
    /// External owner should initialize and provide the view model. It manages selection and CRUD.
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
        .screenBackground()
        .navigationTitle("Income")
        // MARK: Toolbar (+ button) → Present Add Income sheet
        .appToolbar(
            titleDisplayMode: .large,
            trailingItems: [
                .add {
                    // MARK: + Button Action
                    // Use selected date if any; otherwise default to today
                    addIncomeInitialDate = viewModel.selectedDate ?? Date()
                    isPresentingAddIncome = true
                }
            ]
        )
        // Keep list in sync without deprecated APIs
        .modifier(SelectionChangeHandler(viewModel: viewModel))
        // MARK: Present Add Income Form
        .sheet(isPresented: $isPresentingAddIncome, onDismiss: {
            // Reload entries for the selected day after adding/saving
            viewModel.reloadForSelectedDay()
        }) {
            // Prefill First Date using the selected date if available
            AddIncomeFormView(incomeObjectID: nil, budgetObjectID: nil, initialDate: addIncomeInitialDate)
        }
        .onAppear {
            // Initial load (today or previously selected date)
            viewModel.load(day: viewModel.selectedDate ?? Date())
        }
    }
    
    // MARK: Calendar Section
    /// Wraps the `MCalendarView` in a card and applies a stark black and white appearance.
    /// In light mode the background is white with a black selection circle; in dark mode the
    /// background is black with a white selection circle.
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
                .fill(colorScheme == .dark ? Color.black : Color.white)
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
                .fill(colorScheme == .dark ? Color.black : Color.white)
        )
        .accessibilityIdentifier("IncomeCalendar")
#endif
    }
    
    // MARK: Weekly Summary Bar
    /// Small bar that totals the week containing the selected date.
    @ViewBuilder
    private var weeklySummaryBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .imageScale(.large)
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
                .fill(colorScheme == .dark ? Color.black : Color.white)
                .shadow(radius: 1, y: 1)
        )
    }
    
    // MARK: Selected Day Section (WITH swipe to delete)
    /// Displays the selected date and a list of income entries for that day.
    /// The list supports native swipe-to-delete on iOS & macOS; it also scrolls
    /// when tall, while preserving the “pill” styling.
    private var selectedDaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            let date = viewModel.selectedDate ?? Date()
            let entries = viewModel.incomesForDay
            
            // MARK: Section Title — Selected Day
            Text(DateFormatter.localizedString(from: date, dateStyle: .full, timeStyle: .none))
                .font(.headline)
                .padding(.bottom, DS.Spacing.xs)
            
            if entries.isEmpty {
                // MARK: Empty State (no income on this date)
                Text("No income for \(formattedDate(date)).")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                    .padding(.vertical, 4)
            } else {
                // MARK: Scrollable List with Swipe to Delete (like Presets)
                List {
                    ForEach(entries) { income in
                        // MARK: Income Row
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
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        // MARK: Swipe Actions (iOS & macOS)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                viewModel.delete(income: income)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    // MARK: .onDelete for keyboard/delete key & trailing swipe (parity with Presets)
                    .onDelete { indexSet in
                        let targets = indexSet.compactMap { idx in entries[safe: idx] }
                        targets.forEach { viewModel.delete(income: $0) }
                    }
                }
                .listStyle(.plain)
#if os(iOS)
                .scrollIndicators(.hidden)
#endif
                .scrollContentBackground(.hidden) // keep our pill background visible
                // Keep the "pill" compact; enable scrolling when there are many rows.
                .frame(minHeight: 60, maxHeight: 120) // ↓ slightly smaller than before
                // IMPORTANT: Do NOT clip the List; clipping rounds the swipe-action background
                // on the first row (top-right corner). Keeping the outer container rounded
                // preserves the pill look without cutting the swipe actions.
                // .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))  ← keep removed
            }
        }
        .padding()
        // MARK: Full-width pill on macOS (and iOS)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .fill(colorScheme == .dark ? Color.black : Color.white)
                .shadow(radius: 1, y: 1)
        )
    }
    
    // MARK: Helpers
    
    /// Formats a date for short UI display (e.g., "Aug 14, 2025").
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
        // Fallback: assume week starts on current calendar's firstWeekday
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
}

// MARK: - SelectionChangeHandler
/// Bridges `onChange` without deprecated macOS 14 signatures; reloads when selectedDate changes.
/// - Behavior: Calls `viewModel.reloadForSelectedDay()` whenever `selectedDate` changes.
/// - Compatibility:
///   - macOS 14 / iOS 17 and later → uses the zero-parameter closure.
///   - Earlier OS versions → falls back to the single-parameter closure.
private struct SelectionChangeHandler: ViewModifier {
    @ObservedObject var viewModel: IncomeScreenViewModel
    func body(content: Content) -> some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            // New signature (zero-parameter or two-parameter). We only need to react, not inspect values.
            return content.onChange(of: viewModel.selectedDate) {
                viewModel.reloadForSelectedDay()
            }
        } else {
            // Legacy signature (single-parameter).
            return content.onChange(of: viewModel.selectedDate) { _ in
                viewModel.reloadForSelectedDay()
            }
        }
    }
}

// MARK: - Custom Calendar Day View (UBDayView / UBWeekdaysView / UBMonthLabel)
// ... existing implementations you already have in this file ...

// MARK: - Array Safe Indexing (for onDelete index safety)
private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
