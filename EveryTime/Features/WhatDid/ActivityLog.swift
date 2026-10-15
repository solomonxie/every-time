import SwiftUI

/// A tap on the What did page: the moment something started. It runs until the next mark.
struct ActivityMark: Identifiable, Codable, Hashable {
    var id = UUID()
    var time: Date
    /// A built-in activity id or a custom name; nil until tagged.
    var tag: String?
    /// Planned (ahead of now) and wants a notification when its time comes.
    var alarm: Bool?
    /// "daily": in the editor, repeat as an `ActivityRule`; stored only by older versions.
    var repeats: String?

    var isDaily: Bool { repeats == "daily" }
}

struct Activity: Hashable, Identifiable {
    let id: String
    let title: String
    let symbol: String
    let tint: Color
    /// A point in time, not a stretch: it doesn't end what was going on.
    var isMoment = false
    /// Often named after the fact ("just woke up"): a tap asks Start or End. Everything else just starts.
    var asksEnd = false

    static let sleep = Activity(id: "sleep", title: "Sleep", symbol: "bed.double.fill", tint: .indigo, asksEnd: true)
    static let eat = Activity(id: "eat", title: "Eat", symbol: "fork.knife", tint: .green, asksEnd: true)
    /// How a sleep under 3 h shows; its tag stays "sleep".
    static let napLook = Activity(id: "sleep", title: "Nap", symbol: "moon.zzz.fill", tint: .purple, asksEnd: true)
    static let coffee = Activity(id: "coffee", title: "Coffee", symbol: "cup.and.saucer.fill", tint: .brown, isMoment: true)
    static let untagged = Activity(id: "", title: "Untagged", symbol: "questionmark.circle", tint: .gray)

    /// The tiles. Sleep isn't one: it comes from the Sleep page.
    static let builtIn: [Activity] = [
        eat, coffee,
        Activity(id: "work", title: "Work", symbol: "laptopcomputer", tint: .blue),
        Activity(id: "study", title: "Study", symbol: "book.fill", tint: .cyan),
        Activity(id: "workout", title: "Workout", symbol: "figure.run", tint: .red),
        Activity(id: "commute", title: "Commute", symbol: "car.fill", tint: .teal),
        Activity(id: "chores", title: "Chores", symbol: "bubbles.and.sparkles.fill", tint: .yellow),
        Activity(id: "rest", title: "Rest", symbol: "sofa.fill", tint: .mint),
        Activity(id: "fun", title: "Fun", symbol: "gamecontroller.fill", tint: .pink),
        Activity(id: "phone", title: "Phone", symbol: "iphone", tint: Color(red: 0.55, green: 0.55, blue: 0.6)),
        Activity(id: "washup", title: "Wash up", symbol: "shower.fill", tint: Color(red: 0.3, green: 0.65, blue: 0.9), asksEnd: true),
        Activity(id: "church", title: "Church", symbol: "building.columns.fill", tint: Color(red: 0.55, green: 0.4, blue: 0.75)),
    ]

    static func of(_ tag: String?) -> Activity {
        guard let tag, !tag.isEmpty else { return untagged }
        if tag == sleep.id { return sleep }
        if let known = builtIn.first(where: { $0.id == tag }) { return known }
        if let feeling = Feeling.of(tag: tag) { return feeling.activity }
        let style = customStyles[tag] ?? TagStyle()
        return Activity(id: tag, title: tag, symbol: style.symbol, tint: style.tint)
    }

    /// Icon and colour per custom tag; the page keeps this in step with what's stored.
    nonisolated(unsafe) static var customStyles: [String: TagStyle] = AppData.defaults.decoded(ActivityLog.stylesKey) ?? [:]
}

/// How a custom tag looks.
struct TagStyle: Codable, Equatable {
    var symbol = "tag.fill"
    var color = "gray"

    var tint: Color { Self.colors.first { $0.name == color }?.color ?? .gray }

    static let colors: [(name: String, color: Color)] = [
        ("red", .red), ("orange", .orange), ("yellow", .yellow), ("green", .green), ("mint", .mint), ("teal", .teal),
        ("cyan", .cyan), ("blue", .blue), ("indigo", .indigo), ("purple", .purple), ("pink", .pink), ("brown", .brown), ("gray", .gray),
    ]

    static let symbols = [
        "tag.fill", "star.fill", "heart.fill", "flag.fill", "book.fill", "pencil", "graduationcap.fill", "music.note", "headphones",
        "tv.fill", "film.fill", "gamecontroller.fill", "camera.fill", "paintbrush.fill", "phone.fill", "bubble.left.fill", "person.2.fill",
        "cart.fill", "bag.fill", "dollarsign.circle.fill", "house.fill", "hammer.fill", "wrench.fill", "desktopcomputer",
        "figure.walk", "figure.run", "bicycle", "dumbbell.fill", "bus.fill", "car.fill", "airplane", "tram.fill",
        "fork.knife", "cup.and.saucer.fill", "wineglass.fill", "pills.fill", "cross.case.fill", "drop.fill", "bed.double.fill", "zzz",
        "leaf.fill", "tree.fill", "pawprint.fill", "sun.max.fill", "moon.fill", "cloud.fill", "flame.fill", "bolt.fill", "sparkles",
    ]
}

/// One mark's stretch of time, up to the next mark (or now).
struct ActivitySpan: Identifiable, Hashable {
    let id: UUID
    let tag: String?
    let start: Date
    let end: Date
    let isOpen: Bool
    /// A daily pin's occurrence on a later day: not stored; `source` is the pin it comes from.
    var source: UUID? = nil
    var isDaily = false

    /// A finished sleep under 3 h reads as a nap.
    var activity: Activity {
        tag == Activity.sleep.id && !isOpen && duration < Night.minLength && end > start ? Activity.napLook : .of(tag)
    }
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
    static let stylesKey = "timers.activityTagStyles"
    static let orderKey = "timers.activityOrder"
    /// The last mark stops running after this long with nothing after it: yesterday's coffee isn't still going on.
    static let maxOpen: TimeInterval = 12 * 3600

    var marks: [ActivityMark]
    var rules: [ActivityRule] = []
    var calendar = Calendar.current

    var current: ActivityMark? { marks.max { $0.time < $1.time } }

    /// Days ahead of now a daily pin is shown for.
    static let repeatDays = 14

    /// Pins ahead of now: plans, plus each daily pin's next days. Each runs to the next plan, else for `maxOpen` within its day.
    func planned(at now: Date) -> [ActivitySpan] {
        let horizon = calendar.date(byAdding: .day, value: Self.repeatDays, to: now) ?? now
        let daily = occurrences(through: horizon).filter { $0.mark.time > now }.map { ($0.mark, $0.rule as UUID?) }
        let ahead = (marks.filter { $0.time > now }.map { ($0, nil as UUID?) } + daily).sorted { $0.0.time < $1.0.time }
        return ahead.indices.map { i in
            let (mark, source) = ahead[i]
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: mark.time)) ?? mark.time
            let next = ahead.indices.contains(i + 1) ? ahead[i + 1].0.time : nil
            let end = Activity.of(mark.tag).isMoment ? mark.time : next ?? min(dayEnd, mark.time.addingTimeInterval(Self.maxOpen))
            return ActivitySpan(id: mark.id, tag: mark.tag, start: mark.time, end: end, isOpen: false, source: source, isDaily: source != nil)
        }
    }

    /// Coffee and feelings: pinned, but they don't split the timeline.
    func moments(at now: Date) -> [ActivityMark] {
        pins(through: now).filter { $0.time <= now && Activity.of($0.tag).isMoment }.sorted { $0.time < $1.time }
    }

    /// Oldest first; the last one stays open until `now`, for at most `maxOpen`. Moments are left out.
    func spans(at now: Date) -> [ActivitySpan] {
        let sorted = pins(through: now).filter { $0.time <= now && !Activity.of($0.tag).isMoment }.sorted { $0.time < $1.time }
        return sorted.indices.map { i in
            let next = sorted.indices.contains(i + 1) ? sorted[i + 1].time : nil
            let cap = sorted[i].time.addingTimeInterval(Self.maxOpen)
            return ActivitySpan(id: sorted[i].id, tag: sorted[i].tag, start: sorted[i].time,
                                end: next ?? min(now, cap), isOpen: next == nil && now < cap)
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
        guard let first = pins(through: now).map(\.time).min(), first < now else { return nil }
        let from = calendar.date(byAdding: .day, value: -days, to: now) ?? now
        return DateInterval(start: max(from, first), end: now)
    }

    /// Average time per day for each activity over the last `days` days.
    func dailyAverages(days: Int = 7, at now: Date) -> [ActivityTotal] {
        guard let window = recent(days: days, at: now) else { return [] }
        let dayCount = max(1, (window.duration / 86_400).rounded(.up))
        return totals(in: window, at: now).map { ActivityTotal(tag: $0.tag, time: $0.time / dayCount) }
    }

    /// Finished sleep of `Night.minLength` or more, newest first; back-to-back sleep pins count as one.
    func nights(at now: Date) -> [ActivitySpan] {
        var sleeps: [ActivitySpan] = []
        for span in spans(at: now) where span.tag == Activity.sleep.id {
            if let last = sleeps.last, last.end == span.start {
                sleeps[sleeps.count - 1] = ActivitySpan(id: last.id, tag: last.tag, start: last.start, end: span.end, isOpen: span.isOpen)
            } else {
                sleeps.append(span)
            }
        }
        return sleeps.filter { !$0.isOpen && $0.duration >= Night.minLength }.reversed()
    }

    /// When you last got up: the end of the last night. Nil while asleep.
    func upSince(at now: Date) -> Date? {
        let spans = self.spans(at: now)
        guard let last = spans.last, last.tag != Activity.sleep.id else { return nil }
        guard let end = nights(at: now).first?.end, now.timeIntervalSince(end) < 86_400 else { return nil }
        return end
    }

    func typical(days: Int = 7, at now: Date) -> ActivityTypical {
        guard let window = recent(days: days, at: now) else { return ActivityTypical() }
        let nights = nights(at: now).filter { window.contains($0.end) }
        let meals = pins(through: now).filter { $0.tag == Activity.eat.id && window.contains($0.time) }.count
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

/// Taps on the What did page.
extension ActivityLog {
    /// Pins `activity` at `time` (already rounded) and tags the range it starts or ends.
    /// A pin of the same sort (moment or stretch) within 2 min is reused, so a wrong tap is fixed by tapping the right tag.
    func recording(_ activity: Activity, at time: Date, starts: Bool, now: Date) -> ActivityLog {
        let spans = self.spans(at: now)
        let near = pins(through: time.addingTimeInterval(120)).first {
            abs($0.time.timeIntervalSince(time)) < 120 && Activity.of($0.tag).isMoment == activity.isMoment
        }
        if starts {
            if let near { return settingTag(near.id, activity.id) }
            return appending(ActivityMark(time: time, tag: activity.id))
        }
        guard let ending = spans.last(where: { $0.start < time }) else {
            return appending(ActivityMark(time: time, tag: activity.id))
        }
        if let near, let before = spans.last(where: { $0.start < near.time }) {
            return settingTag(before.id, activity.id)
        }
        return appending(ActivityMark(time: time, tag: nil)).settingTag(ending.id, activity.id)
    }

    /// Changes only the tag; time, repeat and alarm stay. A daily pin's day becomes a pin of its own.
    func settingTag(_ id: UUID, _ tag: String?) -> ActivityLog {
        var log = detaching(id)
        if let i = log.marks.firstIndex(where: { $0.id == id }) { log.marks[i].tag = tag }
        return log
    }

    private func appending(_ mark: ActivityMark) -> ActivityLog {
        var log = self
        log.marks.append(mark)
        return log
    }
}

/// Writes from other pages (the nap alarm), outside SwiftUI views.
extension ActivityLog {
    /// Pins sit on 5-minute steps, rounded down so a new one is never in the future.
    static func rounded(_ time: Date) -> Date {
        Date(timeIntervalSinceReferenceDate: (time.timeIntervalSinceReferenceDate / 300).rounded(.down) * 300)
    }

    /// `nil` ends what was going on without naming what comes next.
    static func record(_ activity: Activity?, at time: Date = .now, in defaults: UserDefaults = AppData.defaults) {
        var marks: [ActivityMark] = defaults.decoded(key) ?? []
        marks.append(ActivityMark(time: rounded(time), tag: activity?.id))
        defaults.encode(marks, key)
    }

    /// Old tags: "nap" is a short "sleep"; a "wake" that ended a sleep stays as its untagged end pin, the rest go.
    static func migrateTags(_ marks: [ActivityMark]) -> [ActivityMark] {
        let sorted = marks.sorted { $0.time < $1.time }
            .map { $0.tag == "nap" ? ActivityMark(id: $0.id, time: $0.time, tag: Activity.sleep.id, alarm: $0.alarm) : $0 }
        return sorted.indices.compactMap { i in
            let mark = sorted[i]
            guard mark.tag == "wake" else { return mark }
            return i > 0 && sorted[i - 1].tag == Activity.sleep.id ? ActivityMark(id: mark.id, time: mark.time, tag: nil, alarm: mark.alarm) : nil
        }
    }

    static let oldTags = ["wake", "nap"]

    static func remove(_ activity: Activity?, at time: Date, in defaults: UserDefaults = AppData.defaults) {
        var marks: [ActivityMark] = defaults.decoded(key) ?? []
        marks.removeAll { $0.tag == activity?.id && ($0.time == time || $0.time == rounded(time)) }
        defaults.encode(marks, key)
    }
}

/// Notifications for planned pins that asked for one.
enum ActivityAlarms {
    private static let prefix = NotificationBudget.Feature.activity.prefix
    /// Days of a daily pin's alarms queued ahead; refreshed each time the app comes forward.
    static let dailyDays = 7

    static func wanted(now: Date) -> [NotificationBudget.Request] { wanted(.stored(), at: now) }

    /// One request per plan with an alarm and per day ahead of a daily pin with one; skipped days and stopped repeats have none.
    static func wanted(_ log: ActivityLog, at now: Date) -> [NotificationBudget.Request] {
        let plans = log.marks.filter { $0.alarm == true && $0.time > now }.map {
            request($0, body: "Planned for \(SleepNow.clock($0.time)).")
        }
        let alarmed = Set(log.rules.filter { $0.alarm == true }.map(\.id))
        let horizon = log.calendar.date(byAdding: .day, value: dailyDays, to: now) ?? now
        let daily = log.occurrences(through: horizon).filter { alarmed.contains($0.rule) && $0.mark.time > now }.map {
            request($0.mark, body: "Every day at \(SleepNow.clock($0.mark.time)).")
        }
        return plans + daily
    }

    private static func request(_ mark: ActivityMark, body: String) -> NotificationBudget.Request {
        NotificationBudget.Request(id: prefix + mark.id.uuidString, feature: .activity, fire: mark.time,
                                   title: Activity.of(mark.tag).title, body: body)
    }
}
