//
//  IncomeCalendarEventStore.swift
//  SoFar
//
//  Created by OpenAI's assistant on 2025-02-14.
//

import Foundation

/// Observable container for calendar income events grouped by day.
/// `IncomeView` updates this store as the visible month changes and
/// `UBDayView` reads from it to display per-day income amounts.
final class IncomeCalendarEventStore: ObservableObject {
    /// Maps a day (start-of-day) to all income events occurring on that day.
    @Published var eventsByDay: [Date: [IncomeService.IncomeEvent]] = [:]
}

