import Foundation
import Testing
@testable import EveryTime

struct SleepPlanTests {
    private let wake = date(2026, 3, 11, 7)

    @Test func bedtimesEndCyclesAtTheWake() {
        #expect(SleepPlan.bedtimes(for: wake).map(\.time) == [date(2026, 3, 11, 2, 15), date(2026, 3, 11, 0, 45),
                                                             date(2026, 3, 10, 23, 15), date(2026, 3, 10, 21, 45)])
    }

    @Test func wakeTimesFromNowLeadWithANap() {
        let rows = SleepPlan.wakeTimes(from: date(2026, 3, 10, 23), includesNap: true)
        #expect(rows.map(\.cycles) == [0, 1, 2, 3, 4, 5, 6])
        #expect(rows[0].time == date(2026, 3, 10, 23, 20))
        #expect(rows[6].time == date(2026, 3, 11, 8, 15))
        #expect(rows.map(\.level) == [.low, .high, .high, .some, .some, .low, .low])
        #expect(SleepPlan.wakeTimes(from: date(2026, 3, 10, 23), includesNap: false).first?.cycles == 1)
    }

    @Test func waitWhenAShortWaitEndsCyclesAtTheWake() {
        let answer = SleepPlan.answer(now: date(2026, 3, 10, 22, 50), wake: wake)
        #expect(answer.nowCycles == 5)
        #expect(answer.nowWake == date(2026, 3, 11, 6, 35))
        #expect(answer.wait?.time == date(2026, 3, 10, 23, 15))
        #expect(!answer.sleepsNow)
    }

    @Test func sleepNowWhenCyclesAlreadyEndNearTheWake() {
        let answer = SleepPlan.answer(now: date(2026, 3, 10, 23, 10), wake: wake)
        #expect(answer.sleepsNow)
        #expect(answer.nowWake == date(2026, 3, 11, 6, 55))
    }

    @Test func underACycleLeft() {
        let answer = SleepPlan.answer(now: date(2026, 3, 11, 6), wake: wake)
        #expect(answer.nowWake == nil)
        #expect(answer.wait == nil)
    }

    @Test func relative() {
        let now = date(2026, 3, 10, 22)
        #expect(SleepPlan.relative(date(2026, 3, 10, 22, 5), now: now) == "now")
        #expect(SleepPlan.relative(date(2026, 3, 10, 23, 20), now: now) == "in 1h 20m")
        #expect(SleepPlan.relative(date(2026, 3, 10, 21), now: now) == "passed")
    }
}

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
