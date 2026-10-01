import Foundation

/// Where a sleep that started at `start` stands at `now`: whole cycles done, and whether this is a good moment to get up.
struct WakeCheck: Equatable {
    static let cycle = SleepSuggestion.cycleLength
    static let fallAsleep = SleepSuggestion.fallAsleepTime
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

/// A rough 0–100 for a night: mostly how much of your usual sleep you got, plus waking between cycles and how you felt.
enum SleepScore {
    static func score(asleep: TimeInterval, usualHours: Double, energy: Int? = nil) -> Int {
        let length = min(1, asleep / (usualHours * 3600)) * 60
        let fit = SleepSuggestion.fit(minutesInBed: Int((asleep + SleepSuggestion.fallAsleepTime) / 60))
        let cycles = fit.isBetweenCycles ? 20.0 : 8
        let feel = energy.map { Double($0 - 1) * 5 } ?? 12
        return Int((length + cycles + feel).rounded())
    }

    static func level(_ score: Int) -> NapAdvice.Level {
        score >= 80 ? .low : score >= 60 ? .some : .high
    }
}

/// What recent nights add up to: sleep owed against your usual hours, and how steady your wake time is.
enum SleepTrend {
    /// Shortfall over the last `days` nights; nights that ran long pay some back.
    static func debt(_ nights: [PastNight], usualHours: Double, days: Int = 7) -> TimeInterval {
        max(0, nights.prefix(days).reduce(0) { $0 + usualHours * 3600 - $1.asleep })
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
