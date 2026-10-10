import Foundation

/// Where a sleep that started at `start` stands at `now`: whole cycles done, and whether this is a good moment to get up.
struct WakeCheck: Equatable {
    static var cycle: TimeInterval { SleepSuggestion.cycleLength }
    static var fallAsleep: TimeInterval { SleepSuggestion.fallAsleepTime }
    /// Within this of a cycle's end counts as at the end.
    static let slack: TimeInterval = 15 * 60

    let start: Date
    let now: Date

    var elapsed: TimeInterval { max(0, now.timeIntervalSince(start)) }
    private var asleep: TimeInterval { max(0, elapsed - Self.fallAsleep) }

    var cycles: Int { Int(asleep / Self.cycle) }
    var isFirstMinutes: Bool { asleep < Self.slack }
    /// Time since the last cycle ended, or into the first one.
    var intoCycle: TimeInterval { asleep - Double(cycles) * Self.cycle }
    var toCycleEnd: TimeInterval { Self.cycle - intoCycle }
    var nextCycleEnd: Date { now.addingTimeInterval(toCycleEnd) }

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
    static let cycleRange = 70...120
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
        return learnedCount > 0 ? "average · \(learnedCount) of \(Self.minWakes) natural wakes so far" : "average until you wake on your own a few times"
    }

    /// The cycle length that best explains when you woke on your own: each wake should land on a cycle's end.
    static func learned(from naps: [Nap], fallAsleep: Int, minCount: Int = minWakes) -> (minutes: Int, count: Int)? {
        let wakes = naps.filter { $0.natural == true }.map { Double($0.minutes - fallAsleep) }.filter { $0 >= 60 }
        guard wakes.count >= minCount else { return nil }
        let best = cycleRange.min { a, b in cost(a, wakes) < cost(b, wakes) } ?? defaultMinutes
        return (best, wakes.count)
    }

    private static func cost(_ length: Int, _ asleep: [Double]) -> Double {
        asleep.reduce(0) { sum, minutes in
            let cycles = max(1, (minutes / Double(length)).rounded())
            return sum + abs(minutes - cycles * Double(length))
        }
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

    /// Shortfall over the last `days` nights; long nights and naps in that time pay it back by the time spent asleep.
    static func debt(_ nights: [PastNight], naps: [Nap] = [], need: TimeInterval, days: Int = 7) -> TimeInterval {
        let recent = nights.prefix(days)
        guard let since = recent.map(\.start).min() else { return 0 }
        let napped = naps.filter { !$0.isNight && $0.start >= since }
            .reduce(0) { $0 + max(0, $1.duration - SleepSuggestion.fallAsleepTime) }
        return max(0, recent.reduce(0) { $0 + need - $1.asleep } - napped)
    }

    /// Newest-first nights in a row that ended within `slack` of the usual wake.
    static func wakeStreak(_ nights: [PastNight], usualWake: Int, slack: Int = 30, calendar: Calendar = .current) -> Int {
        var streak = 0
        for night in nights {
            let parts = calendar.dateComponents([.hour, .minute], from: night.end)
            let minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            let off = abs(minutes - usualWake)
            guard min(off, 1440 - off) <= slack else { break }
            streak += 1
        }
        return streak
    }
}
