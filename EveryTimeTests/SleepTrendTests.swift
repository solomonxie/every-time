import Foundation
import Testing
@testable import EveryTime

struct SleepTrendTests {
    private func night(_ day: Int, wake: Int, hours: Double) -> PastNight {
        let end = date(2026, 3, day, wake / 60, wake % 60)
        return PastNight(start: end.addingTimeInterval(-hours * 3600), end: end, asleep: hours * 3600)
    }

    @Test func debtAddsShortfallAndLongNightsPayBack() {
        let nights = [night(12, wake: 420, hours: 6), night(11, wake: 420, hours: 7), night(10, wake: 420, hours: 9)]
        #expect(SleepTrend.debt(nights, usualHours: 8) == 2 * 3600)
        #expect(SleepTrend.debt([night(12, wake: 420, hours: 10)], usualHours: 8) == 0)
    }

    @Test func streakStopsAtTheFirstOffNight() {
        let nights = [night(12, wake: 420, hours: 8), night(11, wake: 440, hours: 8), night(10, wake: 540, hours: 8), night(9, wake: 420, hours: 8)]
        #expect(SleepTrend.wakeStreak(nights, usualWake: 420, calendar: gregorian()) == 2)
    }
}
