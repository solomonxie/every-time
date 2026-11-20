import SwiftUI

/// Movements tapped within one fixed block of the day: 0:00–2:00, 2:00–4:00…
struct MovementBlock: Equatable {
    let start: Date
    let end: Date
    let count: Int

    init(containing date: Date, hours: Int, events: [LaborEvent], calendar: Calendar = .current) {
        let day = calendar.startOfDay(for: date)
        let hour = calendar.component(.hour, from: date)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: day) ?? date
        start = calendar.date(byAdding: .hour, value: hour / hours * hours, to: day) ?? day
        end = min(calendar.date(byAdding: .hour, value: hours, to: start) ?? nextDay, nextDay)
        count = events.filter { [start, end] in $0.kind == .moved && $0.time >= start && $0.time < end }.count
    }

    func previous(events: [LaborEvent], calendar: Calendar = .current) -> MovementBlock {
        MovementBlock(containing: start.addingTimeInterval(-1), hours: max(1, Int(end.timeIntervalSince(start) / 3600)), events: events, calendar: calendar)
    }

    /// "10:00–12:00"
    var label: String {
        let style = Date.FormatStyle(date: .omitted, time: .shortened)
        return "\(start.formatted(style))–\(end.formatted(style))"
    }
}
