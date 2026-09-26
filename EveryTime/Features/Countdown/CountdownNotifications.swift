import UserNotifications

/// One notification at each future countdown's target. Shares iOS's 64-pending cap with the other
/// schedulers, so at most 10 soonest and never past the free slots.
enum CountdownNotifications {
    private static let prefix = "countdown."
    private static let limit = 10
    private static let systemCap = 64
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
        let countdowns = UserDefaults.standard.data(forKey: Countdown.storageKey)
            .flatMap { try? JSONDecoder().decode([Countdown].self, from: $0) } ?? []
        return countdowns
            .filter { $0.notification && $0.target > now }
            .sorted { $0.target < $1.target }
            .map { countdown in
                let content = UNMutableNotificationContent()
                content.title = "⏰ \(countdown.name) — time's up"
                content.body = countdown.target.formatted(date: .abbreviated, time: .shortened)
                content.sound = countdown.sound ? .default : nil
                let when = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: countdown.target)
                let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: false)
                return UNNotificationRequest(identifier: prefix + countdown.id.uuidString, content: content, trigger: trigger)
            }
    }
}
