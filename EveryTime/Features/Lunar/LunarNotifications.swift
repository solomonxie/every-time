import Foundation

/// 9:00 reminders on the next Gregorian dates of lunar events.
enum LunarNotifications {
    static let storageKey = "calendar.lunar"
    private static let prefix = NotificationBudget.Feature.lunar.prefix
    private static let perEvent = 3
    private static let hour = 9

    static func wanted(now: Date, calendar: Calendar = .current) -> [NotificationBudget.Request] {
        let events: [LunarEvent] = AppData.defaults.decoded(storageKey) ?? []
        return events.filter(\.notify).flatMap { event in
            Lunar.occurrences(of: event, count: perEvent)
                .compactMap { calendar.date(bySettingHour: hour, minute: 0, second: 0, of: $0) }
                .filter { $0 > now }
                .enumerated()
                .map { index, fire in
                    NotificationBudget.Request(id: "\(prefix)\(event.id.uuidString).\(index)", feature: .lunar, fire: fire,
                                               title: "🏮 \(event.name) — today",
                                               body: "农历 \(event.lunar.chinese) · \(fire.formatted(date: .long, time: .omitted))",
                                               floating: true)
                }
        }
    }
}
