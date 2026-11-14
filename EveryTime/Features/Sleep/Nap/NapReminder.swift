import Foundation

/// For a daily napper: a nudge as today's and tomorrow's nap windows open, skipped on a day already napped.
enum NapReminder {
    static func wanted(now: Date) -> [NotificationBudget.Request] {
        guard let profile: JetLagProfile = AppData.defaults.decoded(JetLagKey.profile) else { return [] }
        return requests(advice: NapAdvice(profile: profile), naps: AppData.defaults.decoded(NapKey.naps) ?? [], now: now)
    }

    static func requests(advice: NapAdvice, naps: [Nap], now: Date) -> [NotificationBudget.Request] {
        guard let minutes = advice.profile.dailyNap else { return [] }
        let calendar = advice.calendar
        return (0...1).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { return nil }
            let window = advice.window(on: day)
            guard window.start > now,
                  !SleepSession.group(naps).contains(where: { !$0.isNight && calendar.isDate($0.start, inSameDayAs: window.start) })
            else { return nil }
            return NotificationBudget.Request(id: NotificationBudget.Feature.napReminder.prefix + "\(Int(window.start.timeIntervalSince1970))",
                                              feature: .napReminder, fire: window.start, title: "Nap window open",
                                              body: "A \(minutes)-min nap before \(SleepNow.clock(window.end)) keeps the afternoon dip away.",
                                              floating: true)
        }
    }
}
