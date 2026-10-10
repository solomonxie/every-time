import Foundation
import Testing
@testable import EveryTime

/// Usual 23:00 → 07:00, age 35, on 2026-03-10.
func napAdvice(age: Int = 35, bed: Int = 23 * 60) -> NapAdvice {
    var profile = JetLagProfile()
    profile.age = age
    profile.usualBedtime = bed
    return NapAdvice(profile: profile, calendar: gregorian())
}

struct ClockTimeTests {
    init() { useDefaultCycle() }

    @Test func bedBeforeNoonMeansAfterMidnight() {
        #expect(gregorian().clockTime(minutes: 60, daysAfter: 1, of: date(2026, 3, 10)) == date(2026, 3, 11, 1))
        #expect(gregorian().clockTime(minutes: 23 * 60, of: date(2026, 3, 10)) == date(2026, 3, 10, 23))
    }
}

struct NapAdviceTests {
    init() { useDefaultCycle() }

    @Test func clockChangeDayKeepsWallClockTimes() {
        let newYork = TimeZone(identifier: "America/New_York")!
        var profile = JetLagProfile()
        profile.usualBedtime = 23 * 60
        let advice = NapAdvice(profile: profile, calendar: gregorian(newYork))
        let day = advice.day(of: date(2026, 3, 8, 14, in: newYork))
        #expect(day.wake == date(2026, 3, 8, 7, in: newYork))
        #expect(day.bed == date(2026, 3, 8, 23, in: newYork))
        #expect(day.nextWake == date(2026, 3, 9, 7, in: newYork))
    }

    @Test func usualDay() {
        let day = napAdvice().day(of: date(2026, 3, 10, 14))
        #expect(day.wake == date(2026, 3, 10, 7))
        #expect(day.bed == date(2026, 3, 10, 23))
        #expect(day.nextWake == date(2026, 3, 11, 7))
        #expect(day.nightHours == 8)
    }

    @Test func bedAfterMidnightRollsToNextDay() {
        let day = napAdvice(bed: 60).day(of: date(2026, 3, 10, 14))
        #expect(day.bed == date(2026, 3, 11, 1))
    }

    @Test func beforeWakeStillBelongsToLastNight() {
        let advice = napAdvice()
        #expect(advice.current(at: date(2026, 3, 10, 5)).wake == date(2026, 3, 9, 7))
        #expect(advice.current(at: date(2026, 3, 10, 7)).wake == date(2026, 3, 10, 7))
        #expect(advice.current(at: date(2026, 3, 10, 23, 30)).wake == date(2026, 3, 10, 7))
    }

    @Test func windowIsPostLunchDip() {
        let window = napAdvice().window(on: date(2026, 3, 10))
        #expect(window.start == date(2026, 3, 10, 13))
        #expect(window.end == date(2026, 3, 10, 15, 30))
    }

    @Test func earlyBedCutsWindowButKeepsAnHour() {
        let window = napAdvice(bed: 18 * 60).window(on: date(2026, 3, 10))
        #expect(window.end == date(2026, 3, 10, 14))
    }

    @Test(arguments: [
        (13, 20, NapAdvice.Level.low),
        (13, 90, .some),
        (10, 90, .low),
        (17, 20, .some),
        (20, 30, .high),
    ])
    func tonightLevel(hour: Int, minutes: Int, expected: NapAdvice.Level) {
        #expect(napAdvice().tonight(start: date(2026, 3, 10, hour), minutes: minutes) == expected)
    }

    @Test func olderIsStricter() {
        let start = date(2026, 3, 10, 13)
        #expect(napAdvice().tonight(start: start, minutes: 30) == .low)
        #expect(napAdvice(age: 65).tonight(start: start, minutes: 30) == .some)
    }

    @Test func explicitBedOverridesDay() {
        let start = date(2026, 3, 10, 13)
        #expect(napAdvice().tonight(start: start, minutes: 20, bed: date(2026, 3, 10, 16)) == .high)
    }

    @Test func grogginess() {
        #expect([10, 20, 30, 45, 75, 90, 100, 120].map(NapAdvice.grogginess)
            == [.low, .low, .low, .high, .high, .some, .low, .some])
        #expect(NapAdvice.wakeText(minutes: 90) == "Full cycle — groggy if cut short")
        #expect(NapAdvice.wakeText(minutes: 30) == "Wake up fresh")
        #expect(NapAdvice.wakeText(minutes: 10) == "Wake up fresh")
    }

    @Test func hoursText() {
        #expect(NapAdvice.hours(8) == "8h")
        #expect(NapAdvice.hours(7.5) == "7h 30m")
        #expect(NapAdvice.hours(1.25) == "1h 15m")
    }

    @Test func levelsOrder() {
        #expect(NapAdvice.Level.low < .some && NapAdvice.Level.some < .high)
        #expect(max(NapAdvice.Level.some, .low) == .some)
    }

    @Test func activeNapAlarm() {
        #expect(ActiveNap(start: date(2026, 3, 10, 13), minutes: 20).alarm == date(2026, 3, 10, 13, 20))
        #expect(Nap(start: date(2026, 3, 10, 13), end: date(2026, 3, 10, 12)).minutes == 0)
    }
}
