import Foundation
import Testing
@testable import EveryTime

/// Usual 23:00 → 07:00, age 35, on 2026-03-10.
func napAdvice(age: Int = 35, bed: Int = 23 * 60, plan: NightPlan? = nil) -> NapAdvice {
    var profile = JetLagProfile()
    profile.age = age
    profile.usualBedtime = bed
    return NapAdvice(profile: profile, plan: plan, calendar: gregorian())
}

func tonightPlan(bed: Int, wake: Int) -> NightPlan {
    NightPlan(day: date(2026, 3, 10), bed: bed, wake: wake)
}

struct NightPlanTests {
    @Test func bedBeforeNoonMeansAfterMidnight() {
        #expect(tonightPlan(bed: 60, wake: 480).bedDate() == date(2026, 3, 11, 1))
        #expect(tonightPlan(bed: 23 * 60, wake: 480).bedDate() == date(2026, 3, 10, 23))
        #expect(tonightPlan(bed: 60, wake: 480).wakeDate() == date(2026, 3, 11, 8))
    }
}

struct NapAdviceTests {
    @Test func usualDay() {
        let day = napAdvice().day(of: date(2026, 3, 10, 14))
        #expect(day.wake == date(2026, 3, 10, 7))
        #expect(day.bed == date(2026, 3, 10, 23))
        #expect(day.usualBed == day.bed)
        #expect(day.nextWake == date(2026, 3, 11, 7))
        #expect(day.lateHours == 0)
        #expect(day.nightHours == 8)
    }

    @Test func bedAfterMidnightRollsToNextDay() {
        let day = napAdvice(bed: 60).day(of: date(2026, 3, 10, 14))
        #expect(day.bed == date(2026, 3, 11, 1))
    }

    @Test func plannedNightReplacesUsual() {
        let advice = napAdvice(plan: tonightPlan(bed: 60, wake: 8 * 60))
        let day = advice.day(of: date(2026, 3, 10, 9))
        #expect(day.usualBed == date(2026, 3, 10, 23))
        #expect(day.bed == date(2026, 3, 11, 1))
        #expect(day.nextWake == date(2026, 3, 11, 8))
        #expect(day.lateHours == 2)
        #expect(advice.day(of: date(2026, 3, 11, 9)).bed == date(2026, 3, 11, 23))
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
        #expect(napAdvice().suggestedMinutes(on: date(2026, 3, 10)) == NapAdvice.suggestedMinutes)
    }

    @Test func lateNightStretchesWindowAndSuggestsFullCycle() {
        let advice = napAdvice(plan: tonightPlan(bed: 60, wake: 8 * 60))
        #expect(advice.suggestedMinutes(on: date(2026, 3, 10)) == NapAdvice.longMinutes)
        let window = advice.window(on: date(2026, 3, 10))
        #expect(window.start == date(2026, 3, 10, 13))
        #expect(window.end == date(2026, 3, 10, 16, 30))
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

    @Test func nightNotes() {
        #expect(napAdvice().nightNote(on: date(2026, 3, 10)) == nil)
        #expect(napAdvice(plan: tonightPlan(bed: 60, wake: 8 * 60)).nightNote(on: date(2026, 3, 10))
            == "Late night (7h of sleep) — a 90-minute nap in the window banks sleep ahead of it.")
        let short = napAdvice(plan: tonightPlan(bed: 23 * 60, wake: 6 * 60)).nightNote(on: date(2026, 3, 10))
        #expect(short?.hasPrefix("Short night (7h) — for your usual 8h, be in bed by ") == true)
        #expect(napAdvice(plan: tonightPlan(bed: 22 * 60, wake: 7 * 60)).nightNote(on: date(2026, 3, 10))
            == "Early night — keep naps short and early.")
    }

    @Test func grogginess() {
        #expect([10, 20, 30, 45, 75, 90, 100, 120].map(NapAdvice.grogginess)
            == [.low, .low, .some, .high, .high, .some, .some, .high])
        #expect(NapAdvice.wakeText(minutes: 90) == "Full cycle — groggy if cut short")
        #expect(NapAdvice.wakeText(minutes: 30) == "A little groggy")
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
