import SwiftUI
import UserNotifications

enum NapKey {
    static let naps = "sleep.naps"
    static let active = "sleep.nap.active"
    static let length = "sleep.nap.length"
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

    var profile: JetLagProfile
    var calendar = Calendar.current

    private var isOlder: Bool { profile.age >= 60 }
    private var isYoung: Bool { profile.age < 25 }

    /// Hours between a nap's end and bedtime that keep tonight's effect low / below high.
    private var calmHours: Double { isOlder ? 8 : isYoung ? 6 : 7 }
    private var riskyHours: Double { isOlder ? 5 : isYoung ? 3 : 4 }

    func usualDay(of date: Date) -> (wake: Date, bed: Date) {
        let day = calendar.startOfDay(for: date)
        let wake = day.addingTimeInterval(Double(profile.usualWake) * 60)
        var bed = day.addingTimeInterval(Double(profile.usualBedtime) * 60)
        if bed <= wake { bed.addTimeInterval(86_400) }
        return (wake, bed)
    }

    /// The post-lunch dip, about 6–8½ h after waking, cut off so a 20-minute nap still ends well before bed.
    func window(on date: Date) -> DateInterval {
        let (wake, bed) = usualDay(of: date)
        let start = wake.addingTimeInterval(6 * 3600)
        let latest = bed.addingTimeInterval(-calmHours * 3600 - Double(Self.suggestedMinutes) * 60)
        let end = max(start.addingTimeInterval(3600), min(wake.addingTimeInterval(8.5 * 3600), latest))
        return DateInterval(start: start, end: end)
    }

    func tonight(start: Date, minutes: Int) -> Level {
        let end = start.addingTimeInterval(Double(minutes) * 60)
        let hoursLeft = usualDay(of: start).bed.timeIntervalSince(end) / 3600
        let timing = hoursLeft >= calmHours ? 0 : hoursLeft >= riskyHours ? 1 : 2
        let length = minutes <= (isOlder ? 20 : 30) ? 0 : minutes <= (isOlder ? 60 : 90) ? 1 : 2
        return Level(rawValue: min(2, timing + length)) ?? .high
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
