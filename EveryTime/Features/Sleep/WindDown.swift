import Foundation

/// One notification before a planned bedtime, to start winding down.
enum WindDown {
    static let lead: TimeInterval = 30 * 60

    static func wanted(now: Date) -> [NotificationBudget.Request] {
        guard let nap: ActiveNap = AppData.defaults.decoded(NapKey.active), let request = request(bed: nap.start, now: now)
        else { return [] }
        return [request]
    }

    static func request(bed: Date, now: Date) -> NotificationBudget.Request? {
        let fire = bed.addingTimeInterval(-lead)
        guard fire > now else { return nil }
        return NotificationBudget.Request(id: NotificationBudget.Feature.windDown.prefix, feature: .windDown, fire: fire,
                                          title: "Time to wind down",
                                          body: "Lights low, screens off — in bed by \(SleepNow.clock(bed)).")
    }
}
