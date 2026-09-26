import Foundation

/// Elapsed time, yearly recurrence and wording for important events. Pure; calendar injectable for tests.
enum Anniversary {
    struct Elapsed: Equatable {
        var days: Int
        var years: Int
        var months: Int
        var remainderDays: Int

        var breakdown: String {
            years > 0 ? "\(years) y \(months) mo \(remainderDays) d" : "\(months) mo \(remainderDays) d"
        }
    }

    /// Whole days (negative if in the future) and y/mo/d, day-granular.
    static func elapsed(since date: Date, to now: Date, calendar: Calendar = .current) -> Elapsed {
        let (from, to) = (calendar.startOfDay(for: date), calendar.startOfDay(for: now))
        let days = calendar.dateComponents([.day], from: from, to: to).day ?? 0
        let c = calendar.dateComponents([.year, .month, .day], from: min(from, to), to: max(from, to))
        return Elapsed(days: days, years: c.year ?? 0, months: c.month ?? 0, remainderDays: c.day ?? 0)
    }

    /// The date's month/day in `year`; Feb 29 falls on Feb 28 in non-leap years.
    static func occurrence(of date: Date, in year: Int, calendar: Calendar = .current) -> Date? {
        let md = calendar.dateComponents([.month, .day], from: date)
        var c = DateComponents(year: year, month: md.month, day: md.day)
        if md.month == 2, md.day == 29, !isLeap(year, calendar: calendar) { c.day = 28 }
        return calendar.date(from: c)
    }

    /// First anniversary (year ≥ 1) on or after `now`'s day.
    static func next(of date: Date, from now: Date, calendar: Calendar = .current) -> Date? {
        let today = calendar.startOfDay(for: now)
        let startYear = max(calendar.component(.year, from: date) + 1, calendar.component(.year, from: today))
        for year in startYear...(startYear + 1) {
            if let d = occurrence(of: date, in: year, calendar: calendar), d >= today { return d }
        }
        return nil
    }

    /// Anniversary number of `anniversary` for an event on `date`.
    static func years(at anniversary: Date, since date: Date, calendar: Calendar = .current) -> Int {
        calendar.component(.year, from: anniversary) - calendar.component(.year, from: date)
    }

    static func days(from now: Date, to date: Date, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
    }

    struct Countdown: Equatable {
        var value: Int
        var unit: String
        /// Finer breakdown, e.g. "5h 12m", "6 wk 3 d", "2 y 4 mo · 850 days".
        var detail: String
    }

    /// Time left until `date`, in the unit that fits: minutes < 1h, hours < 48h (timed events),
    /// days < 2 weeks, weeks < 3 months, months < 2 years, then years.
    static func countdown(to date: Date, from now: Date, hasTime: Bool, calendar: Calendar = .current) -> Countdown {
        let seconds = max(0, date.timeIntervalSince(now))
        if hasTime && seconds < 3600 {
            let m = Int((seconds / 60).rounded(.up))
            return Countdown(value: m, unit: m == 1 ? "minute" : "minutes", detail: "at \(date.formatted(date: .omitted, time: .shortened))")
        }
        if hasTime && seconds < 48 * 3600 {
            let total = Int(seconds / 60), h = total / 60, m = total % 60
            return Countdown(value: h, unit: h == 1 ? "hour" : "hours", detail: "\(h)h \(m)m")
        }
        let d = days(from: now, to: date, calendar: calendar)
        let c = calendar.dateComponents([.year, .month, .day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date))
        let (y, mo, rd) = (c.year ?? 0, c.month ?? 0, c.day ?? 0)
        switch d {
        case ..<14:
            return Countdown(value: d, unit: d == 1 ? "day" : "days", detail: d == 1 ? "tomorrow" : date.formatted(.dateTime.weekday(.wide)))
        case ..<91:
            return Countdown(value: d / 7, unit: d / 7 == 1 ? "week" : "weeks", detail: "\(d / 7) wk \(d % 7) d · \(d) days")
        case ..<730:
            let months = y * 12 + mo
            return Countdown(value: months, unit: months == 1 ? "month" : "months", detail: "\(months) mo \(rd) d · \(d) days")
        default:
            return Countdown(value: y, unit: "years", detail: "\(y) y \(mo) mo · \(d) days")
        }
    }

    static func ordinal(_ n: Int) -> String {
        let suffix: String
        switch (n % 10, n % 100) {
        case (_, 11...13): suffix = "th"
        case (1, _): suffix = "st"
        case (2, _): suffix = "nd"
        case (3, _): suffix = "rd"
        default: suffix = "th"
        }
        return "\(n)\(suffix)"
    }

    /// "Turns 34", "34th birthday 🎂", "5th wedding anniversary", "5 years since", "5 years since Moved to SF".
    static func phrase(_ type: EventType, years n: Int, name: String, isToday: Bool) -> String {
        let yearsSince = "\(n) \(n == 1 ? "year" : "years") since"
        switch type {
        case .birthday: return isToday ? "\(ordinal(n)) birthday 🎂" : "Turns \(n)"
        case .wedding: return isToday ? "\(ordinal(n)) wedding anniversary" : "\(ordinal(n)) anniversary"
        case .anniversary, .relationship: return "\(ordinal(n)) anniversary"
        case .memorial: return yearsSince
        case .milestone, .other: return "\(yearsSince) \(name)"
        }
    }

    /// Whether the phrase already names the event.
    static func phraseIncludesName(_ type: EventType) -> Bool {
        type == .milestone || type == .other
    }

    private static func isLeap(_ year: Int, calendar: Calendar) -> Bool {
        guard let feb = calendar.date(from: DateComponents(year: year, month: 2)) else { return false }
        return calendar.range(of: .day, in: .month, for: feb)?.count == 29
    }
}
