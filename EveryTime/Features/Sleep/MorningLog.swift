import Foundation

/// The morning after a night the app didn't see: what to log, and usual hours read off past nights.
enum MorningLog {
    /// Last night at the usual hours; only in the first hours after the usual wake when neither the app nor Health saw a night.
    static func proposal(now: Date, naps: [Nap], health: [PastNight], advice: NapAdvice) -> Nap? {
        let calendar = advice.calendar
        let day = advice.day(of: now)
        guard now >= day.wake, now < day.wake.addingTimeInterval(5 * 3600) else { return nil }
        guard !naps.contains(where: { $0.isNight && now.timeIntervalSince($0.end) < 14 * 3600 }),
              !health.contains(where: { calendar.isDate($0.end, inSameDayAs: now) })
        else { return nil }
        let bed = advice.day(of: calendar.date(byAdding: .day, value: -1, to: now) ?? now).bed
        return Nap(start: bed, end: day.wake)
    }

    static func key(_ date: Date, calendar: Calendar = .current) -> String {
        calendar.startOfDay(for: date).formatted(.iso8601.year().month().day())
    }

    /// Median bed and wake, as minutes after midnight, once there are a week of nights.
    static func usualHours(from nights: [PastNight], calendar: Calendar = .current) -> (bed: Int, wake: Int)? {
        guard nights.count >= 7 else { return nil }
        // Bedtimes straddle midnight: measure them from noon so the median isn't split.
        let beds = nights.map { (calendar.minutesOfDay($0.start) + 12 * 60) % (24 * 60) }.sorted()
        let wakes = nights.map { calendar.minutesOfDay($0.end) }.sorted()
        let round = { (m: Int) in (m + 2) / 5 * 5 }
        return (bed: round((beds[beds.count / 2] + 12 * 60) % (24 * 60)), wake: round(wakes[wakes.count / 2]))
    }
}
