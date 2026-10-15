import Foundation

/// One notification per event: at its time while it's ahead, then at 9:00 on its next anniversary (the ordinal changes yearly).
enum ImportantEventNotifications {
    private static let prefix = NotificationBudget.Feature.event.prefix
    private static let hour = 9

    static func wanted(now: Date, calendar: Calendar = .current) -> [NotificationBudget.Request] {
        let events: [ImportantEvent] = AppData.defaults.decoded(ImportantEvent.storageKey) ?? []
        return events.filter(\.notify).compactMap { event in
            guard let (day, fire) = nextFire(for: event, now: now, calendar: calendar) else { return nil }
            let years = Anniversary.years(at: day, since: event.date, calendar: calendar)
            return NotificationBudget.Request(
                id: prefix + event.id.uuidString, feature: .event, fire: fire,
                title: years == 0 ? "⏰ \(event.name) — it's here" : ImportantEventCopy.todayTitle(event, years: years),
                body: "\(event.name) · \(event.date.formatted(date: .long, time: .omitted))",
                floating: !(event.hasTime && fire == event.date))
        }
    }

    /// The event itself while it's ahead (its time, or 9:00 for all-day), then the next anniversary whose 9:00 is ahead.
    private static func nextFire(for event: ImportantEvent, now: Date, calendar: Calendar) -> (Date, Date)? {
        let arrival = event.hasTime ? event.date : calendar.date(bySettingHour: hour, minute: 0, second: 0, of: event.date)
        if let arrival, arrival > now { return (calendar.startOfDay(for: event.date), arrival) }
        var from = now
        for _ in 0..<2 {
            guard let day = Anniversary.next(of: event.date, from: from, calendar: calendar),
                  let fire = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) else { return nil }
            if fire > now { return (day, fire) }
            from = calendar.date(byAdding: .day, value: 1, to: day) ?? day
        }
        return nil
    }
}

/// Shared wording for the Today card and notifications.
enum ImportantEventCopy {
    static func todayTitle(_ event: ImportantEvent, years: Int) -> String {
        let phrase = Anniversary.phrase(event.type, years: years, name: event.name, isToday: true)
        let emoji = event.type == .memorial ? "🕯" : "🎉"
        return Anniversary.phraseIncludesName(event.type) ? "\(emoji) \(phrase)" : "\(emoji) \(phrase) — \(event.name)"
    }
}
