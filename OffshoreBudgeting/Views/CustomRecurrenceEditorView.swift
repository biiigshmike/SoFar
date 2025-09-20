//
//  CustomRecurrenceEditorView.swift
//  SoFar
//
//  Created by Michael Brown on 8/13/25.
//

import SwiftUI

// MARK: - CustomRecurrence
/// Lightweight model for building a simple RRULE:
/// - Units: Day / Week / Month / Year
/// - Interval: 1...30
/// - Optional weekdays (only if unit == week)
struct CustomRecurrence: Equatable {
    enum Unit: String, CaseIterable, Identifiable {
        case day = "Day", week = "Week", month = "Month", year = "Year"
        var id: String { rawValue }

        var icsFreq: String {
            switch self {
            case .day: return "DAILY"
            case .week: return "WEEKLY"
            case .month: return "MONTHLY"
            case .year: return "YEARLY"
            }
        }
    }

    var unit: Unit = .week
    var interval: Int = 2
    var selectedWeekdays: Set<Weekday> = [.monday, .wednesday, .friday]

    /// Render to a minimal ICS RRULE string, e.g.:
    /// - DAILY;INTERVAL=3
    /// - WEEKLY;INTERVAL=2;BYDAY=MO,WE,FR
    func toRRULE() -> String {
        var parts: [String] = ["FREQ=\(unit.icsFreq)"]
        if interval > 1 { parts.append("INTERVAL=\(interval)") }
        if unit == .week, !selectedWeekdays.isEmpty {
            let byday = selectedWeekdays.map { $0.icsCode }.sorted().joined(separator: ",")
            parts.append("BYDAY=\(byday)")
        }
        return parts.joined(separator: ";")
    }

    /// Very rough parse to seed UI (best-effort, safe on unknown).
    static func roughParse(rruleString: String) -> CustomRecurrence {
        let upper = rruleString.uppercased()
        var seed = CustomRecurrence()
        if upper.contains("FREQ=DAILY") { seed.unit = .day }
        else if upper.contains("FREQ=WEEKLY") { seed.unit = .week }
        else if upper.contains("FREQ=MONTHLY") { seed.unit = .month }
        else if upper.contains("FREQ=YEARLY") { seed.unit = .year }

        if let intPart = upper.split(separator: ";").first(where: { $0.hasPrefix("INTERVAL=") }) {
            let num = intPart.split(separator: "=").last.flatMap { Int($0) } ?? 1
            seed.interval = max(1, min(30, num))
        }

        if seed.unit == .week,
           let by = upper.split(separator: ";").first(where: { $0.hasPrefix("BYDAY=") })?.split(separator: "=").last {
            let codes = by.split(separator: ",").map(String.init)
            let wds = codes.compactMap { Weekday.fromICS($0) }
            seed.selectedWeekdays = Set(wds)
        }
        return seed
    }
}

// MARK: - CustomRecurrenceEditorView
/// Modal sheet to build a simple custom recurrence RRULE.
/// Returns a `CustomRecurrence` to the caller for storage in `RecurrenceRule.custom`.
struct CustomRecurrenceEditorView: View {
    // MARK: Inputs
    let initial: CustomRecurrence
    let onCancel: () -> Void
    let onSave: (CustomRecurrence) -> Void

    // MARK: State
    @State private var draft: CustomRecurrence
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager

    // MARK: Init
    init(initial: CustomRecurrence,
         onCancel: @escaping () -> Void,
         onSave: @escaping (CustomRecurrence) -> Void) {
        self.initial = initial
        self.onCancel = onCancel
        self.onSave = onSave
        _draft = State(initialValue: initial)
    }

    // MARK: Body
    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                NavigationStack {
                    content
                        .navigationTitle("Custom Recurrence")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") {
                                    onCancel()
                                    dismiss()
                                }
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Save") {
                                    onSave(draft)
                                    dismiss()
                                }
                                .bold()
                            }
                        }
                }
            } else {
                NavigationView {
                    content
                        .navigationTitle("Custom Recurrence")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") {
                                    onCancel()
                                    dismiss()
                                }
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Save") {
                                    onSave(draft)
                                    dismiss()
                                }
                                .fontWeight(.bold)
                            }
                        }
                }
                .navigationViewStyle(StackNavigationViewStyle())
            }
        }
        .ub_navigationGlassBackground(
            baseColor: themeManager.selectedTheme.glassBaseColor,
            configuration: themeManager.glassConfiguration
        )
    }

    // Extracted content to reuse between NavigationStack and NavigationView
    private var content: some View {
        Form {
            Section {
                Picker("Every", selection: $draft.interval) {
                    ForEach(1...30, id: \.self) { i in
                        Text("\(i)").tag(i)
                    }
                }
                Picker("Unit", selection: $draft.unit) {
                    ForEach(CustomRecurrence.Unit.allCases) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
            } header: {
                Text("FREQUENCY")
                    .font(.footnote).foregroundStyle(.secondary).textCase(.none)
            }

            if draft.unit == .week {
                Section {
                    WeekdayMultiPicker(selection: $draft.selectedWeekdays)
                } header: {
                    Text("WEEKDAYS")
                        .font(.footnote).foregroundStyle(.secondary).textCase(.none)
                }
            }

            Section {
                Text("Preview")
                    .font(.subheadline).foregroundStyle(.secondary)
                if #available(iOS 16.0, *) {
                    Text(draft.toRRULE())
                        .font(.callout).monospaced()
                        .textSelection(.enabled)
                } else {
                    Text(draft.toRRULE())
                        .font(.system(.callout, design: .monospaced))
                }
            }
        }
    }

    // MARK: Subviews
    /// Multi-select weekdays control using checkmarks
    private struct WeekdayMultiPicker: View {
        @Binding var selection: Set<Weekday>

        var body: some View {
            ForEach(Weekday.allCases) { day in
                Button {
                    toggle(day)
                } label: {
                    HStack {
                        Text(day.displayName)
                        Spacer()
                        if selection.contains(day) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }

        private func toggle(_ day: Weekday) {
            if selection.contains(day) { selection.remove(day) }
            else { selection.insert(day) }
        }
    }
}

// MARK: - AddIncomeFormViewModel (Custom Hook)
extension AddIncomeFormViewModel {
    /// Applies a custom recurrence selection to the view model.
    func applyCustomRecurrence(_ custom: CustomRecurrence) {
        self.recurrenceRule = .custom(custom.toRRULE(), endDate: recurrenceEndDate(from: recurrenceRule))
        self.customRuleSeed = custom
    }

    /// Extracts endDate from a rule.
    private func recurrenceEndDate(from rr: RecurrenceRule) -> Date? {
        switch rr {
        case .none: return nil
        case .daily(let d), .weekly(_, let d), .biWeekly(_, let d),
             .semiMonthly(_, _, let d), .monthly(let d), .quarterly(let d),
             .annually(let d), .custom(_, let d): return d
        }
    }
}
