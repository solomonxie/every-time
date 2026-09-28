import Foundation

struct SleepSuggestion: Identifiable, Equatable {
    static let cycleLength: TimeInterval = 90 * 60
    static let fallAsleepTime: TimeInterval = 15 * 60
    static let cycleCounts = [6, 5, 4, 3]
    static let recommendedCycles = 5...6

    let time: Date
    let cycles: Int

    var id: Int { cycles }
    var hours: Double { Double(cycles) * Self.cycleLength / 3600 }
    var isRecommended: Bool { Self.recommendedCycles.contains(cycles) }

    static func bedtimes(wakingAt wake: Date) -> [SleepSuggestion] {
        cycleCounts.map { n in
            SleepSuggestion(time: wake.addingTimeInterval(-fallAsleepTime - Double(n) * cycleLength), cycles: n)
        }
    }

    static func wakeTimes(goingToBedAt bed: Date) -> [SleepSuggestion] {
        cycleCounts.map { n in
            SleepSuggestion(time: bed.addingTimeInterval(fallAsleepTime + Double(n) * cycleLength), cycles: n)
        }
    }

    /// Cycles in a night of `minutes` in bed, and whether waking lands within 15 minutes of a cycle's end.
    static func fit(minutesInBed minutes: Int) -> (cycles: Int, isBetweenCycles: Bool) {
        let cycles = max(0, (Double(minutes) * 60 - fallAsleepTime) / cycleLength)
        let nearest = cycles.rounded()
        let isBetween = nearest >= 1 && abs(cycles - nearest) * cycleLength <= 15 * 60 + 1
        return (isBetween ? Int(nearest) : Int(cycles), isBetween)
    }

    /// Next time the clock reads `minutes` after midnight, strictly after `now`.
    static func nextOccurrence(ofMinutes minutes: Int, after now: Date, calendar: Calendar = .current) -> Date {
        calendar.nextDate(after: now, matching: DateComponents(hour: minutes / 60, minute: minutes % 60),
                          matchingPolicy: .nextTime) ?? now
    }
}
