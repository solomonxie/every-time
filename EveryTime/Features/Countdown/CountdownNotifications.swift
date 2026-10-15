import Foundation

/// One time's-up notification at each future countdown's target.
enum CountdownNotifications {
    private static let prefix = NotificationBudget.Feature.countdown.prefix

    static func id(_ countdown: UUID) -> String { prefix + countdown.uuidString }

    static func wanted(now: Date) -> [NotificationBudget.Request] {
        let countdowns: [Countdown] = AppData.defaults.decoded(Countdown.storageKey) ?? []
        return countdowns
            .filter { $0.notification && $0.target > now }
            .map { countdown in
                NotificationBudget.Request(id: id(countdown.id), feature: .countdown, fire: countdown.target,
                                           title: "⏰ \(countdown.name) — time's up",
                                           body: countdown.target.formatted(date: .abbreviated, time: .shortened),
                                           sound: countdown.sound, timeSensitive: true)
            }
    }
}
