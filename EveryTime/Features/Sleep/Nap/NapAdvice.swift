import SwiftUI

enum NapKey {
    static let naps = "sleep.naps"
    static let active = "sleep.nap.active"
}

extension Calendar {
    /// Wall-clock `minutes` after midnight, `daysAfter` days from `date`'s day; DST-safe.
    func clockTime(minutes: Int, daysAfter: Int = 0, of date: Date) -> Date {
        let day = self.date(byAdding: .day, value: daysAfter, to: startOfDay(for: date)) ?? date
        return self.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day) ?? day
    }

    /// Wall-clock minutes after midnight.
    func minutesOfDay(_ date: Date) -> Int {
        let c = dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
}

struct Nap: Identifiable, Codable, Hashable {
    var id = UUID()
    var start: Date
    var end: Date
    /// How rested you felt on waking, 1 (drained) to 5 (fresh).
    var energy: Int?
    /// Woke on your own, before the alarm (or with none): these teach your cycle length.
    var natural: Bool?
    /// Started from "+20 min" / "+1 cycle" after waking.
    var resleep: Bool?

    var minutes: Int { max(0, Int(end.timeIntervalSince(start) / 60)) }
    var duration: TimeInterval { end.timeIntervalSince(start) }
    var isNight: Bool { !EveryTime.Night.isNap(duration) }
    /// Slept from the app rather than logged afterwards.
    var isTracked: Bool { natural != nil }

    /// Back to sleep soon after a night, or from the wake screen: falls asleep in minutes.
    func isResleep(among naps: [Nap]) -> Bool {
        resleep == true || naps.contains { $0.isNight && $0.id != id && (0..<PastNight.resleepWindow).contains(start.timeIntervalSince($0.end)) }
    }

    static let energyRange = 1...5
    /// The three the wake screen asks for: drained, OK, fresh.
    static let energyChoices = [1, 3, 5]

    static func energyTitle(_ level: Int) -> String {
        switch level {
        case ...1: "Drained"
        case 2: "Tired"
        case 3: "OK"
        case 4: "Good"
        default: "Fresh"
        }
    }

    static func energySymbol(_ level: Int) -> String {
        switch level {
        case ...1: "battery.0percent"
        case 2: "battery.25percent"
        case 3: "battery.50percent"
        case 4: "battery.75percent"
        default: "battery.100percent"
        }
    }
}

/// A nap in progress; survives relaunch.
struct ActiveNap: Codable, Equatable {
    var start: Date
    var minutes: Int
    /// Alarm turned off part-way: sleep on until "I'm up".
    var alarmOff: Bool?
    /// Back to sleep right after waking, which takes only a few minutes.
    var resleep: Bool?
    var alarm: Date { start.addingTimeInterval(Double(minutes) * 60) }
    var fallAsleep: TimeInterval { resleep == true ? WakeCheck.fallBackAsleep : SleepSuggestion.fallAsleepTime }
    var ringsAlarm: Bool { alarmOff != true }
    var isNap: Bool { Night.isNap(Double(minutes) * 60, resleep: resleep == true) }
}

/// Rule-of-thumb nap guidance from usual sleep hours and age. A rough guide, not a sleep model.
struct NapAdvice {
    enum Level: Int, Comparable {
        case low, some, high
        static func < (a: Level, b: Level) -> Bool { a.rawValue < b.rawValue }
    }

    static var lengths: [Int] { [10, 20, 30, longMinutes] }
    static let suggestedMinutes = 20
    /// Falling asleep plus one cycle, on a 5-minute mark.
    static var longMinutes: Int { (Int((SleepSuggestion.fallAsleepTime + SleepSuggestion.cycleLength) / 60) - 1) / 5 * 5 }

    var profile: JetLagProfile
    var calendar = Calendar.current

    private var isOlder: Bool { profile.age >= 60 }
    private var isYoung: Bool { profile.age < 25 }

    /// Hours between a nap's end and bedtime that keep tonight's effect low / below high.
    private var calmHours: Double { isOlder ? 8 : isYoung ? 6 : 7 }
    private var riskyHours: Double { isOlder ? 5 : isYoung ? 3 : 4 }

    struct Day {
        var wake: Date
        var bed: Date
        var nextWake: Date

        var nightHours: Double { nextWake.timeIntervalSince(bed) / 3600 }
    }

    /// This morning's usual wake, then tonight's bed and tomorrow's wake.
    func day(of date: Date) -> Day {
        let start = calendar.startOfDay(for: date)
        let wake = calendar.clockTime(minutes: profile.usualWake, of: start)
        var bed = calendar.clockTime(minutes: profile.usualBedtime, of: start)
        if bed <= wake { bed = calendar.clockTime(minutes: profile.usualBedtime, daysAfter: 1, of: start) }
        return Day(wake: wake, bed: bed, nextWake: calendar.clockTime(minutes: profile.usualWake, daysAfter: 1, of: start))
    }

    /// The day `date` belongs to: before the planned wake it's still last night.
    func current(at date: Date) -> Day {
        let previous = day(of: calendar.date(byAdding: .day, value: -1, to: date) ?? date)
        return date < previous.nextWake ? previous : day(of: date)
    }

    /// The post-lunch dip, from about 6 h after waking, cut off so the suggested nap still ends well before bed.
    func window(on date: Date) -> DateInterval {
        let day = day(of: date)
        let start = day.wake.addingTimeInterval(6 * 3600)
        let cap = day.wake.addingTimeInterval(8.5 * 3600)
        let latest = day.bed.addingTimeInterval(-calmHours * 3600 - Double(Self.suggestedMinutes) * 60)
        let end = max(start.addingTimeInterval(3600), min(cap, latest))
        return DateInterval(start: start, end: end)
    }

    /// The bed a nap at `start` eats into: tonight's, or past it, the next one.
    func nextBed(after start: Date) -> Date {
        let bed = current(at: start).bed
        return bed > start ? bed : day(of: start).bed
    }

    /// Later and longer naps weigh more; a long nap is fine with plenty of waking time left before bed.
    func tonight(start: Date, minutes: Int, bed: Date? = nil) -> Level {
        let end = start.addingTimeInterval(Double(minutes) * 60)
        let hoursLeft = (bed ?? nextBed(after: start)).timeIntervalSince(end) / 3600
        let timing = hoursLeft >= calmHours ? 0 : hoursLeft >= riskyHours ? 1 : 2
        let length = hoursLeft >= calmHours + 3 || minutes <= (isOlder ? 20 : 30) ? 0
            : minutes <= (isOlder ? 60 : Self.longMinutes) ? 1 : 2
        return Level(rawValue: min(2, timing + length)) ?? .high
    }

    static func hours(_ value: Double) -> String {
        let minutes = Int((value * 60).rounded())
        return minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes / 60)h \(minutes % 60)m"
    }

    /// Same timing as the ring: groggy from deep sleep until near the cycle's end.
    static func grogginess(minutes: Int) -> Level {
        switch WakeFit.nap(length: Double(minutes) * 60) {
        case .good: .low
        case .okay: .some
        case .poor: .high
        }
    }

    static func tonightText(_ level: Level) -> String {
        switch level {
        case .low: "Little effect on tonight"
        case .some: "May fall asleep later tonight"
        case .high: "Likely to delay tonight's sleep"
        }
    }

    static func wakeText(minutes: Int) -> String {
        if minutes >= longMinutes, grogginess(minutes: minutes) == .low { return "Full cycle — wake up fresh" }
        return switch grogginess(minutes: minutes) {
        case .low: "Wake up fresh"
        case .some: minutes > 60 ? "Full cycle — groggy if cut short" : "A little groggy"
        case .high: "Groggy for a while"
        }
    }

    static let info = """
        Rough guide, not medical advice. 10–30 minutes in bed refreshes without grogginess; \
        45–75 reaches deep sleep, so waking feels heavy; 90–100 ends a full cycle. The later \
        and longer a nap, the more it eats into the sleep pressure you need at bedtime. \
        Limits are stricter from age 60 and looser under 25. Sex isn't used: there's no \
        well-established difference for naps.
        """
}

extension NapAdvice.Level {
    var tint: Color {
        switch self {
        case .low: Theme.Tone.good
        case .some: Theme.Tone.warn
        case .high: Theme.Tone.bad
        }
    }
}
