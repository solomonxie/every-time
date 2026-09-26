import UserNotifications

/// Local notifications at each action start; iOS keeps at most 64 pending, so jet lag takes the next 40 and leaves room for important events.
enum JetLagNotifications {
    private static let prefix = "jetlag."
    private static let limit = 40
    private static let silentKinds: Set<ActionKind> = [.flight, .caffeineOK]
    @MainActor private static var queue: Task<Void, Never>?

    /// Replaces all pending jet lag notifications from stored profile and trips.
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
        let stale = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: stale)

        let requests = upcomingRequests(now: .now)
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
        guard let profile = load(JetLagProfile.self, JetLagKey.profile), profile.notifications else { return [] }
        let trips = load([Trip].self, JetLagKey.trips) ?? []
        let items = trips.filter(\.notifications).flatMap { trip in
            trip.plan(for: profile).days.flatMap { day in
                day.actions.map { (id: "\(prefix)\(trip.id.uuidString).\($0.id)", action: $0, timeZone: day.timeZone) }
            }
        }
        var seen = Set<String>()
        return items
            .filter { !silentKinds.contains($0.action.kind) && $0.action.start > now && seen.insert($0.id).inserted }
            .sorted { $0.action.start < $1.action.start }
            .prefix(limit)
            .map { item in
                let content = UNMutableNotificationContent()
                (content.title, content.body) = copy(for: item.action, in: item.timeZone)
                content.sound = .default
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: item.action.start.timeIntervalSince(now), repeats: false)
                return UNNotificationRequest(identifier: item.id, content: content, trigger: trigger)
            }
    }

    private static func copy(for action: PlanAction, in timeZone: TimeZone) -> (String, String) {
        let end = action.end.time(in: timeZone)
        switch action.kind {
        case .brightLight: return ("☀️ See bright light", "Until \(end) — get outside or near a window")
        case .someLight: return ("🌤 Some light is fine", "Until \(end)")
        case .avoidLight: return ("🕶 Avoid bright light", "Until \(end) — sunglasses, dim room")
        case .caffeineAvoid: return ("☕️ No more caffeine", "Until bedtime at \(end)")
        case .sleep: return ("🌙 Time to sleep", "Wake at \(end)")
        case .sleepIfYouCan: return ("🌙 Sleep if you can", "Until \(end)")
        case .nap: return ("😴 Nap if you can", "20–30 minutes")
        case .melatonin: return ("💊 Melatonin", "0.5 mg now")
        case .caffeineOK, .flight: return (action.kind.title, "")
        }
    }

    private static func load<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
        UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }
}
