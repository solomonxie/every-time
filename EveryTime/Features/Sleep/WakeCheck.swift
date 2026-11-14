import Foundation

/// Cycle ends of a sleep that started at `start`: asleep after `latency`, then one every `cycle`.
struct CycleGrid: Equatable {
    let start: Date
    let latency: TimeInterval
    let cycle: TimeInterval

    var asleep: Date { start.addingTimeInterval(latency) }

    func end(_ n: Int) -> Date { asleep.addingTimeInterval(Double(n) * cycle) }

    /// The first cycle end after `date`.
    func next(after date: Date) -> Date {
        end(max(0, Int((date.timeIntervalSince(asleep) / cycle).rounded(.down))) + 1)
    }

    func ends(from: Date = .distantPast, through: Date) -> [Date] {
        let first = max(1, Int((from.timeIntervalSince(asleep) / cycle).rounded(.up)))
        return Array(sequence(first: first) { $0 + 1 }.lazy.map(end).prefix { $0 <= through })
    }
}

/// Where a sleep that started at `start` stands at `now`: whole cycles done, and whether this is a good moment to get up.
struct WakeCheck: Equatable {
    static var cycle: TimeInterval { SleepSuggestion.cycleLength }
    static var fallAsleep: TimeInterval { SleepSuggestion.fallAsleepTime }
    /// Within this of a cycle's end counts as at the end.
    static let slack: TimeInterval = 15 * 60
    /// Falling back asleep after a short wake, e.g. a toilet trip, is much quicker than at bedtime.
    static let fallBackAsleep: TimeInterval = 5 * 60

    let start: Date
    let now: Date
    var latency = Self.fallAsleep

    var grid: CycleGrid { CycleGrid(start: start, latency: latency, cycle: Self.cycle) }
    var elapsed: TimeInterval { max(0, now.timeIntervalSince(start)) }
    private var asleep: TimeInterval { max(0, elapsed - latency) }

    var cycles: Int { Int(asleep / Self.cycle) }
    var isFirstMinutes: Bool { asleep < Self.slack }
    /// Time since the last cycle ended, or into the first one.
    var intoCycle: TimeInterval { asleep - Double(cycles) * Self.cycle }
    var nextCycleEnd: Date { grid.next(after: now) }
    var toCycleEnd: TimeInterval { nextCycleEnd.timeIntervalSince(now) }

    var isAtCycleEnd: Bool { !isFirstMinutes && (intoCycle <= Self.slack || toCycleEnd <= Self.slack) }

    var headline: String {
        if isFirstMinutes { return "Just dozed off" }
        if isAtCycleEnd { return "At a cycle's end" }
        return "Mid-cycle"
    }

    var detail: String {
        let done = cycles + (toCycleEnd <= Self.slack ? 1 : 0)
        let cyclesText = "\(done) \(done == 1 ? "cycle" : "cycles")"
        if isFirstMinutes { return "Not asleep long enough to count." }
        if isAtCycleEnd { return "\(cyclesText) · a good moment to get up" }
        return "\(cyclesText) done · \(Int(toCycleEnd / 60)) min to the next end, ~\(SleepNow.clock(nextCycleEnd))"
    }
}

/// Personal cycle timing: fall-asleep time you set; cycle length yours, or learned from when you wake on your own,
/// else from Health's sleep stages, else the 90-minute average.
struct SleepCycle: Codable, Equatable {
    static let key = "sleep.cycle"
    static let defaultMinutes = 90
    static let fallAsleepRange = 5...45
    static let cycleRange = 60...120
    /// Natural wakes needed before the learned length counts.
    static let minWakes = 5

    var fallAsleepMinutes = 15
    var usesHealth = true
    /// Set by hand; nil = learn.
    var manualMinutes: Int?
    var learnedMinutes: Int?
    var learnedCount = 0
    var healthMinutes: Int?
    var healthCount = 0

    var minutes: Int { manualMinutes ?? learnedMinutes ?? (usesHealth ? healthMinutes : nil) ?? Self.defaultMinutes }

    /// Where the length in use comes from, for the page.
    var sourceText: String {
        if manualMinutes != nil { return "set by you" }
        if learnedMinutes != nil { return "learned from \(learnedCount) natural wakes" }
        if usesHealth, healthMinutes != nil { return "from \(healthCount) Watch sleep cycles" }
        if learnedCount >= Self.minWakes { return "average · \(learnedCount) natural wakes don't line up on one length" }
        return learnedCount > 0 ? "average · \(learnedCount) of \(Self.minWakes) natural wakes so far" : "average until you wake on your own a few times"
    }

    /// The cycle length that best explains when you woke on your own: each wake should land on a cycle's end.
    /// Misses are in cycles, not minutes, so shorter lengths don't win just by having closer ends.
    /// Cycles drift from one to the next, so a short sleep says more than a long one and weighs more.
    static func learned(from naps: [Nap], fallAsleep: Int, minCount: Int = minWakes) -> (minutes: Int, count: Int)? {
        let quick = Int(WakeCheck.fallBackAsleep / 60)
        let wakes = naps.filter { $0.natural == true }
            .map { Double($0.minutes - ($0.isResleep(among: naps) ? quick : fallAsleep)) }
            .filter { $0 >= 60 }
        guard wakes.count >= minCount,
              let best = cycleRange.min(by: { miss($0, wakes) < miss($1, wakes) }),
              miss(best, wakes) <= maxMiss(wakes) else { return nil }
        return (best, wakes.count)
    }

    /// Weighted mean distance from each wake to its nearest cycle end, as a share of a cycle (0–0.5; random wakes ≈ 0.25).
    static func miss(_ length: Int, _ asleep: [Double]) -> Double {
        let weighted = asleep.reduce(0) { sum, minutes in
            let cycles = minutes / Double(length)
            return sum + abs(cycles - max(1, cycles.rounded())) / minutes
        }
        return weighted / asleep.reduce(0) { $0 + 1 / $1 }
    }

    /// Two standard deviations better than random wakes (uniform miss: sd 1/√48), for the evidence the weights leave.
    private static func maxMiss(_ asleep: [Double]) -> Double {
        let weights = asleep.map { 1 / $0 }
        let effective = pow(weights.reduce(0, +), 2) / weights.reduce(0) { $0 + $1 * $1 }
        return 0.25 - 2 / sqrt(48 * effective)
    }

    /// Re-reads your natural wakes and stores the length they point to.
    static func relearn(from naps: [Nap]) {
        var cycle = current
        let learned = learned(from: naps, fallAsleep: cycle.fallAsleepMinutes)
        cycle.learnedMinutes = learned?.minutes
        cycle.learnedCount = learned?.count ?? naps.filter { $0.natural == true }.count
        if cycle != current { current = cycle }
    }

    /// Health-derived values live under a key outside `BackupSnapshot.keyPrefixes`, so they never reach iCloud Drive.
    static let healthKey = "health.sleepCycle"
    private enum CodingKeys: String, CodingKey { case fallAsleepMinutes, usesHealth, manualMinutes, learnedMinutes, learnedCount }
    private struct FromHealth: Codable { var minutes: Int?; var count: Int }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fallAsleepMinutes = try c.decodeIfPresent(Int.self, forKey: .fallAsleepMinutes) ?? 15
        usesHealth = try c.decodeIfPresent(Bool.self, forKey: .usesHealth) ?? true
        manualMinutes = try c.decodeIfPresent(Int.self, forKey: .manualMinutes)
        learnedMinutes = try c.decodeIfPresent(Int.self, forKey: .learnedMinutes)
        learnedCount = try c.decodeIfPresent(Int.self, forKey: .learnedCount) ?? 0
    }

    static var current: SleepCycle {
        get {
            var cycle: SleepCycle = AppData.defaults.decoded(key) ?? SleepCycle()
            if let health: FromHealth = AppData.defaults.decoded(healthKey) {
                cycle.healthMinutes = health.minutes
                cycle.healthCount = health.count
            }
            return cycle
        }
        set {
            AppData.defaults.encode(newValue, key)
            AppData.defaults.encode(FromHealth(minutes: newValue.healthMinutes, count: newValue.healthCount), healthKey)
            newValue.apply()
        }
    }

    func apply() {
        SleepSuggestion.cycleLength = Double(minutes) * 60
        SleepSuggestion.fallAsleepTime = Double(fallAsleepMinutes) * 60
    }
}

/// A rough 0–100 for a night: mostly how much of the sleep you need you got, plus waking between cycles and how you felt.
enum SleepScore {
    static func score(asleep: TimeInterval, need: TimeInterval, energy: Int? = nil) -> Int {
        let length = min(1, asleep / need) * 60
        let fit = SleepSuggestion.fit(minutesInBed: Int((asleep + SleepSuggestion.fallAsleepTime) / 60))
        let cycles = fit.isBetweenCycles ? 20.0 : 8
        let feel = energy.map { Double($0 - 1) * 5 } ?? 12
        return Int((length + cycles + feel).rounded())
    }

    static func level(_ score: Int) -> NapAdvice.Level {
        score >= 80 ? .low : score >= 60 ? .some : .high
    }
}

/// What recent nights add up to: sleep owed against what you need, and how steady your wake time is.
enum SleepTrend {
    /// Sleep a night should hold: your usual hours less the time to fall asleep, but never under the
    /// minimum sleep bodies recommend (AASM/SRS: 7 h for adults, 8 h for teens).
    static func need(_ profile: JetLagProfile) -> TimeInterval {
        max(profile.sleepHours * 3600 - SleepSuggestion.fallAsleepTime, (profile.age < 18 ? 8 : 7) * 3600)
    }

    /// Asleep time a daily nap adds to each day's need, counted the way a nap pays debt back.
    static func napNeed(_ profile: JetLagProfile) -> TimeInterval {
        profile.dailyNap.map { max(0, Double($0) * 60 - SleepSuggestion.fallAsleepTime) } ?? 0
    }

    /// Shortfall per wake day over the last `days` days; a second long sleep that day, long nights and naps
    /// pay it back by the time spent asleep.
    static func debt(_ nights: [PastNight], naps: [Nap] = [], need: TimeInterval, napNeed: TimeInterval = 0, days: Int = 7,
                     now: Date = .now, calendar: Calendar = .current) -> TimeInterval {
        guard let from = calendar.date(byAdding: .day, value: 1 - days, to: calendar.startOfDay(for: now)) else { return 0 }
        let recent = nights.filter { $0.end >= from }
        guard let since = recent.map(\.start).min() else { return 0 }
        let byDay = Dictionary(grouping: recent) { calendar.startOfDay(for: $0.end) }.values
            .map { $0.reduce(0) { $0 + $1.asleep } }
        let napped = SleepSession.group(naps).filter { !$0.isNight && $0.start >= since }
            .reduce(0) { $0 + $1.asleep }
        return max(0, byDay.reduce(0) { $0 + need + napNeed - $1 } - napped)
    }

    /// Nap windows, newest first, that passed with no nap on a day with a night; only for a daily napper.
    static func missedNaps(_ nights: [PastNight], naps: [Nap], advice: NapAdvice, now: Date) -> [DateInterval] {
        guard advice.profile.dailyNap != nil else { return [] }
        let calendar = advice.calendar
        let napped = Set(SleepSession.group(naps).filter { !$0.isNight && !$0.parts[0].isResleep(among: naps) }
            .map { calendar.startOfDay(for: $0.start) })
        return Set(nights.map { calendar.startOfDay(for: $0.end) }).subtracting(napped)
            .map { advice.window(on: $0) }
            .filter { $0.end <= now }
            .sorted { $0.start > $1.start }
    }

    /// Days in a row, newest first, whose night ended within `slack` of the usual wake; a day with no night breaks it.
    static func wakeStreak(_ nights: [PastNight], usualWake: Int, slack: Int = 30, calendar: Calendar = .current) -> Int {
        var streak = 0
        var last: Date?
        for night in nights {
            let day = calendar.startOfDay(for: night.end)
            if day == last { continue }
            if let last, calendar.dateComponents([.day], from: day, to: last).day != 1 { break }
            let off = abs(calendar.minutesOfDay(night.end) - usualWake)
            guard min(off, 1440 - off) <= slack else { break }
            streak += 1
            last = day
        }
        return streak
    }
}
