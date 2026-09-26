import SwiftUI
import UserNotifications

enum NapKey {
    static let naps = "sleep.naps"
    static let active = "sleep.nap.active"
    static let length = "sleep.nap.length"
    static let night = "sleep.nap.night"
}

/// Tonight's bedtime and tomorrow's wake, when they differ from usual; only counts on `day`.
struct NightPlan: Codable, Equatable {
    var day: Date
    /// Minutes after midnight; before noon means after midnight.
    var bed: Int
    var wake: Int

    func bedDate(calendar: Calendar = .current) -> Date {
        let date = day.addingTimeInterval(Double(bed) * 60)
        return bed < 12 * 60 ? date.addingTimeInterval(86_400) : date
    }

    func wakeDate(calendar: Calendar = .current) -> Date {
        day.addingTimeInterval(86_400 + Double(wake) * 60)
    }
}

struct Nap: Identifiable, Codable, Hashable {
    /// How that night's sleep went, rated the next day.
    enum Night: String, Codable, CaseIterable, Identifiable {
        case good, slow, poor
        var id: String { rawValue }
    }

    var id = UUID()
    var start: Date
    var end: Date
    var night: Night?
    /// That night's planned bedtime, if it wasn't the usual one.
    var bed: Date?

    var minutes: Int { max(0, Int(end.timeIntervalSince(start) / 60)) }
}

/// A nap in progress; survives relaunch.
struct ActiveNap: Codable, Equatable {
    var start: Date
    var minutes: Int
    var alarm: Date { start.addingTimeInterval(Double(minutes) * 60) }
}

/// Rule-of-thumb nap guidance from usual sleep hours and age. A rough guide, not a sleep model.
struct NapAdvice {
    enum Level: Int, Comparable {
        case low, some, high
        static func < (a: Level, b: Level) -> Bool { a.rawValue < b.rawValue }
    }

    static let lengths = [10, 20, 30, 90]
    static let suggestedMinutes = 20
    static let longMinutes = 90

    var profile: JetLagProfile
    var plan: NightPlan?
    var calendar = Calendar.current

    private var isOlder: Bool { profile.age >= 60 }
    private var isYoung: Bool { profile.age < 25 }

    /// Hours between a nap's end and bedtime that keep tonight's effect low / below high.
    private var calmHours: Double { isOlder ? 8 : isYoung ? 6 : 7 }
    private var riskyHours: Double { isOlder ? 5 : isYoung ? 3 : 4 }

    struct Day {
        var wake: Date
        var usualBed: Date
        var bed: Date
        var nextWake: Date

        var lateHours: Double { bed.timeIntervalSince(usualBed) / 3600 }
        var nightHours: Double { nextWake.timeIntervalSince(bed) / 3600 }
    }

    /// This morning's usual wake, then tonight's bed and tomorrow's wake (planned or usual).
    func day(of date: Date) -> Day {
        let start = calendar.startOfDay(for: date)
        let wake = start.addingTimeInterval(Double(profile.usualWake) * 60)
        var usualBed = start.addingTimeInterval(Double(profile.usualBedtime) * 60)
        if usualBed <= wake { usualBed.addTimeInterval(86_400) }
        let nextWake = wake.addingTimeInterval(86_400)
        guard let plan, calendar.isDate(plan.day, inSameDayAs: start) else {
            return Day(wake: wake, usualBed: usualBed, bed: usualBed, nextWake: nextWake)
        }
        return Day(wake: wake, usualBed: usualBed, bed: plan.bedDate(), nextWake: plan.wakeDate())
    }

    /// A full cycle before a night that runs 2+ h late banks sleep; otherwise a short refresher.
    func suggestedMinutes(on date: Date) -> Int {
        day(of: date).lateHours >= 2 ? Self.longMinutes : Self.suggestedMinutes
    }

    /// The post-lunch dip, from about 6 h after waking, cut off so the suggested nap still ends well before bed.
    func window(on date: Date) -> DateInterval {
        let day = day(of: date)
        let start = day.wake.addingTimeInterval(6 * 3600)
        let cap = day.wake.addingTimeInterval((8.5 + max(0, day.lateHours)) * 3600)
        let latest = day.bed.addingTimeInterval(-calmHours * 3600 - Double(suggestedMinutes(on: date)) * 60)
        let end = max(start.addingTimeInterval(3600), min(cap, latest))
        return DateInterval(start: start, end: end)
    }

    /// Later and longer naps weigh more; a long nap is fine with plenty of waking time left before bed.
    func tonight(start: Date, minutes: Int, bed: Date? = nil) -> Level {
        let end = start.addingTimeInterval(Double(minutes) * 60)
        let hoursLeft = (bed ?? day(of: start).bed).timeIntervalSince(end) / 3600
        let timing = hoursLeft >= calmHours ? 0 : hoursLeft >= riskyHours ? 1 : 2
        let length = hoursLeft >= calmHours + 3 || minutes <= (isOlder ? 20 : 30) ? 0
            : minutes <= (isOlder ? 60 : 90) ? 1 : 2
        return Level(rawValue: min(2, timing + length)) ?? .high
    }

    /// One line on how tonight's plan changes the advice, if it does.
    func nightNote(on date: Date) -> String? {
        let day = day(of: date)
        if day.lateHours >= 2 {
            return "Late night (\(Self.hours(day.nightHours)) of sleep) — a \(Self.longMinutes)-minute nap in the window banks sleep ahead of it."
        }
        if profile.sleepHours - day.nightHours >= 0.5 {
            let bedBy = day.nextWake.addingTimeInterval(-profile.sleepHours * 3600)
            return "Short night (\(Self.hours(day.nightHours))) — for your usual \(Self.hours(profile.sleepHours)), be in bed by \(bedBy.formatted(date: .omitted, time: .shortened)). Keep any nap short and early."
        }
        if day.lateHours <= -1 {
            return "Early night — keep naps short and early."
        }
        return nil
    }

    static func hours(_ value: Double) -> String {
        let minutes = Int((value * 60).rounded())
        return minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes / 60)h \(minutes % 60)m"
    }

    /// Past ~30 minutes you reach deep sleep and wake groggy, until a full ~90-minute cycle ends.
    static func grogginess(minutes: Int) -> Level {
        switch minutes {
        case ...20: .low
        case ...30: .some
        case ...75: .high
        case ...100: .some
        default: .high
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
        switch grogginess(minutes: minutes) {
        case .low: "Wake up fresh"
        case .some: minutes > 60 ? "Full cycle — groggy if cut short" : "A little groggy"
        case .high: "Groggy for a while"
        }
    }

    static let info = """
        Rough guide, not medical advice. 10–20 minutes refreshes without grogginess; \
        30–75 reaches deep sleep, so waking feels heavy; ~90 is a full cycle. The later \
        and longer a nap, the more it eats into the sleep pressure you need at bedtime. \
        Limits are stricter from age 60 and looser under 25. Sex isn't used: there's no \
        well-established difference for naps. Rate your nights to see your own pattern.
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

extension Nap.Night {
    var title: String {
        switch self {
        case .good: "Slept well"
        case .slow: "Took longer"
        case .poor: "Slept poorly"
        }
    }

    var symbol: String {
        switch self {
        case .good: "face.smiling"
        case .slow: "hourglass"
        case .poor: "cloud.rain"
        }
    }
}

/// One wake-up alarm for the nap in progress.
enum NapAlarm {
    private static let id = "nap.alarm"

    static func schedule(_ nap: ActiveNap) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        let status = await center.notificationSettings().authorizationStatus
        if status == .notDetermined {
            guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
        } else if status == .denied {
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "Time to get up"
        content.body = "Your \(nap.minutes)-minute nap is over."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, nap.alarm.timeIntervalSinceNow), repeats: false)
        try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}
