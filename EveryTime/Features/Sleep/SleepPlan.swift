import Foundation

/// Pick one end of the night, get the other: bedtimes for a wake time, or wake times for a bedtime.
enum SleepPlan {
    enum Mode: String, Codable, CaseIterable, Identifiable {
        case wake, sleep
        var id: String { rawValue }
        var title: String { self == .wake ? "Wake up at…" : "Go to sleep at…" }
    }

    struct Row: Identifiable, Equatable {
        /// 0 for a short nap.
        let cycles: Int
        let time: Date
        /// From lying down to getting up.
        let length: TimeInterval

        var id: Int { cycles }
        var level: NapAdvice.Level {
            switch cycles {
            case 0, 5...: .low
            case 3...4: .some
            default: .high
            }
        }

        var title: String {
            cycles == 0 ? "Nap \(NapAdvice.suggestedMinutes) min"
                : "\(cycles) \(cycles == 1 ? "cycle" : "cycles") · \(NapAdvice.hours(length / 3600))"
        }
    }

    static let cycle = SleepSuggestion.cycleLength
    static let fallAsleep = SleepSuggestion.fallAsleepTime
    /// A bedtime this close counts as now.
    static let nowSlack: TimeInterval = 10 * 60

    /// Wake times on whole cycles from `bed`, shortest first; from now, a short nap leads.
    static func wakeTimes(from bed: Date, includesNap: Bool) -> [Row] {
        let nap = includesNap ? [Row(cycles: 0, time: bed.addingTimeInterval(Double(NapAdvice.suggestedMinutes) * 60),
                                     length: Double(NapAdvice.suggestedMinutes) * 60)] : []
        return nap + (1...6).map { n in
            let length = fallAsleep + Double(n) * cycle
            return Row(cycles: n, time: bed.addingTimeInterval(length), length: length)
        }
    }

    /// Bedtimes that end whole cycles at `wake`, latest first.
    static func bedtimes(for wake: Date) -> [Row] {
        (3...6).map { n in
            let length = fallAsleep + Double(n) * cycle
            return Row(cycles: n, time: wake.addingTimeInterval(-length), length: length)
        }
    }

    struct Answer: Equatable {
        /// Sleeping now: the last cycle end by the wake time, if any fits.
        let nowWake: Date?
        let nowCycles: Int
        /// The next bedtime that ends cycles exactly at the wake, if it's still ahead.
        let wait: Row?

        var sleepsNow: Bool { wait == nil }
    }

    /// Sleep now, or wait for the next whole-cycle bedtime?
    static func answer(now: Date, wake: Date) -> Answer {
        let cycles = max(0, Int((wake.timeIntervalSince(now) - fallAsleep) / cycle))
        let nowWake = cycles > 0 ? now.addingTimeInterval(fallAsleep + Double(cycles) * cycle) : nil
        let next = bedtimes(for: wake).filter { $0.time > now.addingTimeInterval(nowSlack) && $0.cycles >= cycles }.last
        // Waiting only pays when it isn't the same night shortened: the wait gets you up at the wake, not before it.
        let wait = next.flatMap { row in nowWake.map { wake.timeIntervalSince($0) > nowSlack } ?? true ? row : nil }
        return Answer(nowWake: nowWake, nowCycles: cycles, wait: wait)
    }

    /// "in 1h 20m" · "now" · "passed".
    static func relative(_ time: Date, now: Date) -> String {
        let delta = time.timeIntervalSince(now)
        if abs(delta) <= nowSlack { return "now" }
        return delta < 0 ? "passed" : "in \(ActivityLog.duration(delta))"
    }
}
