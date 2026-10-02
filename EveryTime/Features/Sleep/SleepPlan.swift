import Foundation

/// Wake times on whole cycles, and how much sleep still fits when woken early.
enum SleepPlan {
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

    static var cycle: TimeInterval { SleepSuggestion.cycleLength }
    static var fallAsleep: TimeInterval { SleepSuggestion.fallAsleepTime }
    /// Wake times on whole cycles from `bed`, shortest first; from now, a short nap leads.
    static func wakeTimes(from bed: Date, includesNap: Bool) -> [Row] {
        let nap = includesNap ? [Row(cycles: 0, time: bed.addingTimeInterval(Double(NapAdvice.suggestedMinutes) * 60),
                                     length: Double(NapAdvice.suggestedMinutes) * 60)] : []
        return nap + (1...6).map { n in
            let length = fallAsleep + Double(n) * cycle
            return Row(cycles: n, time: bed.addingTimeInterval(length), length: length)
        }
    }

    /// Woken early: falling asleep again from `now`, the last whole cycle ending by `alarm`.
    static func backToSleep(now: Date, alarm: Date) -> (cycles: Int, time: Date)? {
        let cycles = Int((alarm.timeIntervalSince(now) - fallAsleep) / cycle)
        return cycles > 0 ? (cycles, now.addingTimeInterval(fallAsleep + Double(cycles) * cycle)) : nil
    }
}
