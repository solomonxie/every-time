import Foundation

/// A notification at each action start.
enum JetLagNotifications {
    private static let prefix = NotificationBudget.Feature.jetLag.prefix
    private static let silentKinds: Set<ActionKind> = [.flight, .caffeineOK]

    static func wanted(now: Date) -> [NotificationBudget.Request] {
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
            .map { item in
                let (title, body) = copy(for: item.action, in: item.timeZone)
                return NotificationBudget.Request(id: item.id, feature: .jetLag, fire: item.action.start, title: title, body: body)
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
        case .melatonin: return ("💊 Melatonin", "Suggested time, if your doctor agrees")
        case .caffeineOK, .flight: return (action.kind.title, "")
        }
    }

    private static func load<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
        AppData.defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }
}
