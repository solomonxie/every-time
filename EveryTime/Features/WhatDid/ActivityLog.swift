import SwiftUI

/// A tap on the What did page: the moment something started. It runs until the next mark.
struct ActivityMark: Identifiable, Codable, Hashable {
    var id = UUID()
    var time: Date
    /// A built-in activity id or a custom name; nil until tagged.
    var tag: String?
}

struct Activity: Hashable, Identifiable {
    let id: String
    let title: String
    let symbol: String
    let tint: Color

    static let sleep = Activity(id: "sleep", title: "Sleep", symbol: "bed.double.fill", tint: .indigo)
    static let wake = Activity(id: "wake", title: "Wake up", symbol: "sunrise.fill", tint: .orange)
    static let eat = Activity(id: "eat", title: "Eat", symbol: "fork.knife", tint: .green)
    static let nap = Activity(id: "nap", title: "Nap", symbol: "moon.zzz.fill", tint: .purple)
    static let coffee = Activity(id: "coffee", title: "Coffee", symbol: "cup.and.saucer.fill", tint: .brown)
    static let untagged = Activity(id: "", title: "Untagged", symbol: "questionmark.circle", tint: .gray)

    static let builtIn: [Activity] = [
        sleep, wake, nap, eat, coffee,
        Activity(id: "work", title: "Work", symbol: "laptopcomputer", tint: .blue),
        Activity(id: "study", title: "Study", symbol: "book.fill", tint: .cyan),
        Activity(id: "workout", title: "Workout", symbol: "figure.run", tint: .red),
        Activity(id: "commute", title: "Commute", symbol: "car.fill", tint: .teal),
        Activity(id: "chores", title: "Chores", symbol: "bubbles.and.sparkles.fill", tint: .yellow),
        Activity(id: "rest", title: "Rest", symbol: "sofa.fill", tint: .mint),
        Activity(id: "fun", title: "Fun", symbol: "gamecontroller.fill", tint: .pink),
    ]

    static func of(_ tag: String?) -> Activity {
        guard let tag, !tag.isEmpty else { return untagged }
        return builtIn.first { $0.id == tag } ?? Activity(id: tag, title: tag, symbol: "tag.fill", tint: .gray)
    }
}

/// One mark's stretch of time, up to the next mark (or now).
struct ActivitySpan: Identifiable, Hashable {
    let id: UUID
    let tag: String?
    let start: Date
    let end: Date
    let isOpen: Bool

    var activity: Activity { .of(tag) }
    var duration: TimeInterval { end.timeIntervalSince(start) }

    func overlap(with interval: DateInterval) -> TimeInterval {
        max(0, min(end, interval.end).timeIntervalSince(max(start, interval.start)))
    }
}

struct ActivityTotal: Identifiable, Hashable {
    let tag: String?
    let time: TimeInterval
    var id: String { tag ?? "" }
    var activity: Activity { .of(tag) }
}

/// Typical sleep and meals over recent days.
struct ActivityTypical: Equatable {
    var nights = 0
    /// Minutes after midnight.
    var bed: Int?
    var wake: Int?
    var sleep: TimeInterval?
    var mealsPerDay: Double?
}

/// Marks as one continuous timeline, and what it adds up to.
struct ActivityLog {
    static let key = "timers.activityLog"
    static let tagsKey = "timers.activityTags"
    static let orderKey = "timers.activityOrder"
    /// Shorter sleep than this is a nap, not a night.
    static let minNight: TimeInterval = 3 * 3600

    var marks: [ActivityMark]
    var calendar = Calendar.current

    var current: ActivityMark? { marks.max { $0.time < $1.time } }

    /// Oldest first; the last one stays open until `now`.
    func spans(at now: Date) -> [ActivitySpan] {
        let sorted = marks.filter { $0.time <= now }.sorted { $0.time < $1.time }
        return sorted.indices.map { i in
            let next = sorted.indices.contains(i + 1) ? sorted[i + 1].time : nil
            return ActivitySpan(id: sorted[i].id, tag: sorted[i].tag, start: sorted[i].time,
                                end: next ?? now, isOpen: next == nil)
        }
    }

    /// Time per activity inside `interval`, longest first.
    func totals(in interval: DateInterval, at now: Date) -> [ActivityTotal] {
        var byTag: [String: TimeInterval] = [:]
        for span in spans(at: now) {
            let time = span.overlap(with: interval)
            if time > 0 { byTag[span.tag ?? "", default: 0] += time }
        }
        return byTag.map { ActivityTotal(tag: $0.key.isEmpty ? nil : $0.key, time: $0.value) }
            .sorted { $0.time > $1.time }
    }

    func today(at now: Date) -> DateInterval {
        let start = calendar.startOfDay(for: now)
        return DateInterval(start: start, end: calendar.date(byAdding: .day, value: 1, to: start) ?? now)
    }

    /// The last `days` days up to now, starting no earlier than the first mark.
    func recent(days: Int, at now: Date) -> DateInterval? {
        guard let first = marks.map(\.time).min(), first < now else { return nil }
        let from = calendar.date(byAdding: .day, value: -days, to: now) ?? now
        return DateInterval(start: max(from, first), end: now)
    }

    /// Average time per day for each activity over the last `days` days.
    func dailyAverages(days: Int = 7, at now: Date) -> [ActivityTotal] {
        guard let window = recent(days: days, at: now) else { return [] }
        let dayCount = max(1, (window.duration / 86_400).rounded(.up))
        return totals(in: window, at: now).map { ActivityTotal(tag: $0.tag, time: $0.time / dayCount) }
    }

    /// Finished sleep of 3 h or more, newest first.
    func nights(at now: Date) -> [ActivitySpan] {
        spans(at: now).filter { $0.tag == Activity.sleep.id && !$0.isOpen && $0.duration >= Self.minNight }.reversed()
    }

    /// When you last got up: the end of the last night, or a wake-up mark not right after a nap. Nil while asleep.
    func upSince(at now: Date) -> Date? {
        let spans = spans(at: now)
        guard let last = spans.last, last.tag != Activity.sleep.id else { return nil }
        var candidates = nights(at: now).prefix(1).map(\.end)
        for i in spans.indices where spans[i].tag == Activity.wake.id && (i == 0 || spans[i - 1].tag != Activity.nap.id) {
            candidates.append(spans[i].start)
        }
        return candidates.filter { now.timeIntervalSince($0) < 86_400 }.max()
    }

    func typical(days: Int = 7, at now: Date) -> ActivityTypical {
        guard let window = recent(days: days, at: now) else { return ActivityTypical() }
        let nights = nights(at: now).filter { window.contains($0.end) }
        let meals = marks.filter { $0.tag == Activity.eat.id && window.contains($0.time) }.count
        let dayCount = max(1, (window.duration / 86_400).rounded(.up))
        return ActivityTypical(
            nights: nights.count,
            bed: Self.meanClock(nights.map(\.start), calendar: calendar),
            wake: Self.meanClock(nights.map(\.end), calendar: calendar),
            sleep: nights.isEmpty ? nil : nights.map(\.duration).reduce(0, +) / Double(nights.count),
            mealsPerDay: meals == 0 ? nil : Double(meals) / dayCount)
    }

    /// Circular mean of times of day, so 23:30 and 00:30 average to midnight.
    static func meanClock(_ dates: [Date], calendar: Calendar = .current) -> Int? {
        let angles = dates.map { date -> Double in
            let parts = calendar.dateComponents([.hour, .minute], from: date)
            return Double((parts.hour ?? 0) * 60 + (parts.minute ?? 0)) / 1440 * 2 * .pi
        }
        let x = angles.map(cos).reduce(0, +), y = angles.map(sin).reduce(0, +)
        guard hypot(x, y) > 1e-6 else { return nil }
        let mean = atan2(y, x)
        return Int(((mean < 0 ? mean + 2 * .pi : mean) / (2 * .pi) * 1440).rounded()) % 1440
    }

    /// `7h 30m`
    static func duration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        return minutes < 60 ? "\(minutes)m" : minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes / 60)h \(minutes % 60)m"
    }
}

/// Writes from other pages (the nap alarm), outside SwiftUI views.
extension ActivityLog {
    /// Pins sit on 5-minute steps, rounded down so a new one is never in the future.
    static func rounded(_ time: Date) -> Date {
        Date(timeIntervalSinceReferenceDate: (time.timeIntervalSinceReferenceDate / 300).rounded(.down) * 300)
    }

    static func record(_ activity: Activity, at time: Date = .now, in defaults: UserDefaults = AppData.defaults) {
        var marks: [ActivityMark] = defaults.decoded(key) ?? []
        marks.append(ActivityMark(time: rounded(time), tag: activity.id))
        defaults.encode(marks, key)
    }

    static func remove(_ activity: Activity, at time: Date, in defaults: UserDefaults = AppData.defaults) {
        var marks: [ActivityMark] = defaults.decoded(key) ?? []
        marks.removeAll { $0.tag == activity.id && ($0.time == time || $0.time == rounded(time)) }
        defaults.encode(marks, key)
    }
}
