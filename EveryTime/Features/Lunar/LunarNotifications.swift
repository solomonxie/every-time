import UserNotifications

/// 9:00 reminders on the next Gregorian dates of lunar events. Shares iOS's 64-pending cap with the
/// other schedulers, so at most 10 soonest and never past the free slots.
enum LunarNotifications {
    static let storageKey = "calendar.lunar"
    private static let prefix = "lunar."
    private static let limit = 10
    private static let perEvent = 3
    private static let systemCap = 64
    private static let hour = 9
    @MainActor private static var queue: Task<Void, Never>?

    @MainActor
    static func reschedule(requestingAuthorization: Bool = false) {
        guard AppData.drivesSystem else { return }
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
        let events = AppData.defaults.data(forKey: storageKey)
            .flatMap { try? JSONDecoder().decode([LunarEvent].self, from: $0) } ?? []
        return events.filter(\.notify)
            .flatMap { event in
                Lunar.occurrences(of: event, count: perEvent)
                    .compactMap { calendar.date(bySettingHour: hour, minute: 0, second: 0, of: $0) }
                    .filter { $0 > now }
                    .enumerated()
                    .map { (event: event, index: $0.offset, fire: $0.element) }
            }
            .sorted { $0.fire < $1.fire }
            .map { item in
                let content = UNMutableNotificationContent()
                content.title = "🏮 \(item.event.name) — today"
                content.body = "农历 \(item.event.lunar.chinese) · \(item.fire.formatted(date: .long, time: .omitted))"
                content.sound = .default
                let when = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: item.fire)
                let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: false)
                return UNNotificationRequest(identifier: "\(prefix)\(item.event.id.uuidString).\(item.index)",
                                             content: content, trigger: trigger)
            }
    }
}
