import UserNotifications

/// One non-repeating notification per event at 9:00 on its next anniversary (the ordinal changes yearly).
/// Shares iOS's 64-pending cap with jet lag, so at most 20 and never past the free slots.
enum ImportantEventNotifications {
    private static let prefix = "important."
    private static let limit = 20
    private static let systemCap = 64
    private static let hour = 9
    @MainActor private static var queue: Task<Void, Never>?

    @MainActor
    static func reschedule(requestingAuthorization: Bool = false) {
        let previous = queue
        queue = Task {
            await previous?.value
            await run(requestingAuthorization: requestingAuthorization)
        }
    }

    private static func run(requestingAuthorization: Bool) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier)
        let stale = pending.filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: stale)

        let free = systemCap - (pending.count - stale.count)
        let requests = upcomingRequests(now: .now).prefix(max(0, min(limit, free)))
        guard !requests.isEmpty, await isAuthorized(center, requesting: requestingAuthorization) else { return }
        for request in requests { try? await center.add(request) }
    }

    private static func isAuthorized(_ center: UNUserNotificationCenter, requesting: Bool) async -> Bool {
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined where requesting:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        default:
            return false
        }
    }

    private static func upcomingRequests(now: Date) -> [UNNotificationRequest] {
        let calendar = Calendar.current
        let events = UserDefaults.standard.data(forKey: ImportantEvent.storageKey)
            .flatMap { try? JSONDecoder().decode([ImportantEvent].self, from: $0) } ?? []
        return events.filter(\.notify)
            .compactMap { event -> (event: ImportantEvent, day: Date, fire: Date)? in
                guard let (day, fire) = nextFire(for: event, now: now, calendar: calendar) else { return nil }
                return (event, day, fire)
            }
            .sorted { $0.fire < $1.fire }
            .map { item in
                let years = Anniversary.years(at: item.day, since: item.event.date, calendar: calendar)
                let content = UNMutableNotificationContent()
                content.title = years == 0 ? "⏰ \(item.event.name) — it's here" : ImportantEventCopy.todayTitle(item.event, years: years)
                content.body = "\(item.event.name) · \(item.event.date.formatted(date: .long, time: .omitted))"
                content.sound = .default
                var when = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: item.fire)
                when.second = 0
                let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: false)
                return UNNotificationRequest(identifier: prefix + item.event.id.uuidString, content: content, trigger: trigger)
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
