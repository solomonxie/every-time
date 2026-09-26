import Foundation

enum SleepMode: String, CaseIterable, Identifiable {
    case wakeAt = "Wake at"
    case bedNow = "Sleep now"

    var id: Self { self }
}

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

    /// Next time the clock reads `minutes` after midnight, strictly after `now`.
    static func nextOccurrence(ofMinutes minutes: Int, after now: Date, calendar: Calendar = .current) -> Date {
        calendar.nextDate(after: now, matching: DateComponents(hour: minutes / 60, minute: minutes % 60),
                          matchingPolicy: .nextTime) ?? now
    }
}
