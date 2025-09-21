//
//  RecurrencePickerView.swift
//  SoFar
//
//  Created by Michael Brown on 8/13/25.
//

import SwiftUI

// MARK: - RecurrencePickerView
/// A compact recurrence selector for common presets + custom.
/// Displays an optional end-date control and opens a sheet for advanced/custom rules.
/// Bind to `RecurrenceRule` from your view model.
struct RecurrencePickerView: View {
    // MARK: Bindings
    @Binding var rule: RecurrenceRule
    @Binding var isPresentingCustomEditor: Bool

    // MARK: Local State (UI)
    @State private var selectedPreset: Preset = .none
    @State private var selectedWeekday: Weekday = .monday
    @State private var firstDay: Int = 1
    @State private var secondDay: Int = 15

    /// If `true`, show an End Date row and include it in the rule.
    /// Defaults to `false` so the checkbox starts **unchecked**.
    @State private var hasEndDate: Bool = false
    @State private var endDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()

    // MARK: Preset Options
    enum Preset: String, CaseIterable, Identifiable {
        case none = "None"
        case daily = "Daily"
        case weekly = "Weekly"
        case biWeekly = "Bi-Weekly"
        case semiMonthly = "Semi-Monthly"
        case monthly = "Monthly"
        case quarterly = "Quarterly"
        case annually = "Annually"
        case custom = "Custom…"

        var id: String { rawValue }
    }

    // MARK: Init
    init(rule: Binding<RecurrenceRule>, isPresentingCustomEditor: Binding<Bool>) {
        self._rule = rule
        self._isPresentingCustomEditor = isPresentingCustomEditor
        // UI state is seeded on appear from the incoming rule
    }

    // MARK: Body
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Preset Picker
            Picker("Repeat", selection: $selectedPreset) {
                ForEach(Preset.allCases) { p in
                    Text(p.rawValue).tag(p)
                }
            }
            .ub_onChange(of: selectedPreset) { newValue in
                applyPresetChange(newValue)
            }

            // Contextual Controls
            switch selectedPreset {
            case .weekly, .biWeekly:
                WeekdayPicker(selected: $selectedWeekday)
                    .ub_onChange(of: selectedWeekday) {
                        applyPresetChange(selectedPreset)
                    }
            case .semiMonthly:
                HStack(spacing: 12) {
                    DayOfMonthPicker(title: "First day", selection: $firstDay)
                        .ub_onChange(of: firstDay) {
                            applyPresetChange(selectedPreset)
                        }
                    DayOfMonthPicker(title: "Second day", selection: $secondDay)
                        .ub_onChange(of: secondDay) {
                            applyPresetChange(selectedPreset)
                        }
                }
            default:
                EmptyView()
            }

            // End Date Controls
            Toggle("Set End Date", isOn: $hasEndDate)
                .ub_onChange(of: hasEndDate) {
                    applyPresetChange(selectedPreset)
                }

            if hasEndDate {
                DatePicker("End Date", selection: $endDate, displayedComponents: [.date])
                    .ub_onChange(of: endDate) {
                        applyPresetChange(selectedPreset)
                    }
            }

            // Custom Editor Launch
            if selectedPreset == .custom {
                Button {
                    isPresentingCustomEditor = true
                } label: {
                    Label("Edit Custom Recurrence", systemImage: "calendar.badge.plus")
                }
            }
        }
        .onAppear(perform: seedFromRuleIfNeeded)
    }

    // MARK: Behavior
    /// Maps the current `RecurrenceRule` into UI state on first appear.
    private func seedFromRuleIfNeeded() {
        func extractEnd(_ rr: RecurrenceRule) -> Date? {
            switch rr {
            case .none: return nil
            case .daily(let d), .weekly(_, let d), .biWeekly(_, let d),
                 .semiMonthly(_, _, let d), .monthly(let d), .quarterly(let d),
                 .annually(let d), .custom(_, let d):
                return d
            }
        }

        // Default state if no rule
        if case .none = rule {
            selectedPreset = .none
            hasEndDate = false
            return
        }

        let extractedEnd = extractEnd(rule)
        hasEndDate = (extractedEnd != nil)
        if let d = extractedEnd { endDate = d }

        switch rule {
        case .none:
            selectedPreset = .none
        case .daily:
            selectedPreset = .daily
        case .weekly(let wd, _):
            selectedPreset = .weekly
            selectedWeekday = wd
        case .biWeekly(let wd, _):
            selectedPreset = .biWeekly
            selectedWeekday = wd
        case .semiMonthly(let d1, let d2, _):
            selectedPreset = .semiMonthly
            firstDay = d1
            secondDay = d2
        case .monthly:
            selectedPreset = .monthly
        case .quarterly:
            selectedPreset = .quarterly
        case .annually:
            selectedPreset = .annually
        case .custom:
            selectedPreset = .custom
        }
    }

    /// Applies a user-chosen preset to the bound `RecurrenceRule`.
    private func applyPresetChange(_ preset: Preset) {
        let end = hasEndDate ? endDate : nil
        switch preset {
        case .none:
            rule = .none
        case .daily:
            rule = .daily(endDate: end)
        case .weekly:
            rule = .weekly(weekday: selectedWeekday, endDate: end)
        case .biWeekly:
            rule = .biWeekly(weekday: selectedWeekday, endDate: end)
        case .semiMonthly:
            rule = .semiMonthly(firstDay: firstDay, secondDay: secondDay, endDate: end)
        case .monthly:
            rule = .monthly(endDate: end)
        case .quarterly:
            rule = .quarterly(endDate: end)
        case .annually:
            rule = .annually(endDate: end)
        case .custom:
            // Keep current custom rule if present; otherwise seed a sensible default.
            if case .custom(let raw, _) = rule {
                rule = .custom(raw, endDate: end)
            } else {
                rule = .custom("FREQ=MONTHLY", endDate: end)
            }
        }
    }

    // MARK: Subviews
    /// Weekday segmented control in a compact horizontal layout.
    private struct WeekdayPicker: View {
        @Binding var selected: Weekday

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("Weekday").font(.subheadline).foregroundStyle(.secondary)
                Picker("Weekday", selection: $selected) {
                    ForEach(Weekday.allCases) { day in
                        Text(shortName(for: day)).tag(day)
                    }
                }
                .pickerStyle(.segmented)
            }
        }

        private func shortName(for day: Weekday) -> String {
            switch day {
            case .sunday: return "Sun"
            case .monday: return "Mon"
            case .tuesday: return "Tue"
            case .wednesday: return "Wed"
            case .thursday: return "Thu"
            case .friday: return "Fri"
            case .saturday: return "Sat"
            }
        }
    }

    /// Day of month picker [1...31]
    private struct DayOfMonthPicker: View {
        let title: String
        @Binding var selection: Int

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.subheadline).foregroundStyle(.secondary)
                Picker(title, selection: $selection) {
                    ForEach(1...31, id: \.self) { d in
                        Text("\(d)").tag(d)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }
}
