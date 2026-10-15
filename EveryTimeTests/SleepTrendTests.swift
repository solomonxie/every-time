import Foundation
import Testing
@testable import EveryTime

struct SleepTrendTests {
    init() { useDefaultCycle() }

    private let now = date(2026, 3, 12, 20)

    private func night(_ day: Int, wake: Int, hours: Double) -> PastNight {
        let end = date(2026, 3, day, wake / 60, wake % 60)
        return PastNight(start: end.addingTimeInterval(-hours * 3600), end: end, asleep: hours * 3600)
    }

    @Test func debtAddsShortfallAndLongNightsPayBack() {
        let nights = [night(12, wake: 420, hours: 6), night(11, wake: 420, hours: 7), night(10, wake: 420, hours: 9)]
        #expect(SleepTrend.debt(nights, need: 8 * 3600, now: now, calendar: gregorian()) == 2 * 3600)
        #expect(SleepTrend.debt([night(12, wake: 420, hours: 10)], need: 8 * 3600, now: now, calendar: gregorian()) == 0)
    }

    @Test func daytimeLongSleepPaysDebt() {
        let day = PastNight(start: date(2026, 3, 12, 13), end: date(2026, 3, 12, 16, 30), asleep: 3.5 * 3600)
        #expect(SleepTrend.debt([day, night(12, wake: 420, hours: 6)], need: 8 * 3600, now: now, calendar: gregorian()) == 0)
        let old = [night(12, wake: 420, hours: 6), night(5, wake: 420, hours: 7), night(4, wake: 420, hours: 2)]
        #expect(SleepTrend.debt(old, need: 8 * 3600, now: now, calendar: gregorian()) == 2 * 3600)
    }

    @Test func napsPayBackTheirTimeAsleep() {
        let nights = [night(12, wake: 420, hours: 6)]
        let nap = Nap(start: date(2026, 3, 12, 14), end: date(2026, 3, 12, 14, 45))
        #expect(SleepTrend.debt(nights, naps: [nap], need: 8 * 3600, now: now, calendar: gregorian()) == 2 * 3600 - (45 - 15) * 60)
        let before = Nap(start: date(2026, 3, 11, 14), end: date(2026, 3, 11, 15))
        #expect(SleepTrend.debt(nights, naps: [before], need: 8 * 3600, now: now, calendar: gregorian()) == 2 * 3600)
    }

    @Test func goingBackToSleepCountsOnceAsPartOfTheNight() {
        let logged = [
            Nap(start: date(2026, 3, 11, 23), end: date(2026, 3, 12, 6)),
            Nap(start: date(2026, 3, 12, 6, 10), end: date(2026, 3, 12, 7, 55)),
        ]
        let nights = PastNight.merged(logged: logged, health: [], calendar: gregorian())
        #expect(nights.count == 1)
        #expect(nights[0].asleep == 8.5 * 3600)
        #expect(SleepTrend.debt(nights, naps: logged, need: 9 * 3600, now: now, calendar: gregorian()) == 30 * 60)
    }

    @Test func needIsUsualHoursAsleepButAtLeastTheRecommended() {
        var profile = JetLagProfile()
        profile.usualBedtime = 23 * 60
        profile.usualWake = 7 * 60 + 30
        #expect(SleepTrend.need(profile) == 8.5 * 3600 - SleepSuggestion.fallAsleepTime)
        profile.usualWake = 5 * 60
        #expect(SleepTrend.need(profile) == 7 * 3600)
        profile.age = 16
        #expect(SleepTrend.need(profile) == 8 * 3600)
    }

    @Test func streakStopsAtTheFirstOffNight() {
        let nights = [night(12, wake: 420, hours: 8), night(11, wake: 440, hours: 8), night(10, wake: 540, hours: 8), night(9, wake: 420, hours: 8)]
        #expect(SleepTrend.wakeStreak(nights, usualWake: 420, calendar: gregorian()) == 2)
    }
}
