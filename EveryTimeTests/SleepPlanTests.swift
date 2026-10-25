import Foundation
import Testing
@testable import EveryTime

struct SleepPlanTests {
    init() { useDefaultCycle() }

    private func plan(_ now: Date, kind: SleepKind = .sleep, bed: Date? = nil, wake: Date? = nil, nights: [PastNight] = []) -> SleepPlan {
        SleepPlan.resolve(now: now, kind: kind, napMinutes: 20, pickedBed: bed, pickedWake: wake,
                          profile: JetLagProfile(), nights: nights, calendar: gregorian())
    }

    @Test func napStartsNowForItsLength() {
        let now = date(2026, 3, 10, 14, 3)
        let plan = plan(now, kind: .nap)
        #expect(plan.kind == .nap && plan.napBlocked == nil)
        #expect(plan.choice.bed == now)
        #expect(plan.choice.wake == date(2026, 3, 10, 14, 23))
        #expect(plan.choice.isNap)
    }

    @Test func byDaySleepDefaultsToTheUsualHours() {
        let plan = plan(date(2026, 3, 10, 14))
        #expect(plan.choice.bed == date(2026, 3, 10, 23))
        #expect(plan.choice.wake == date(2026, 3, 11, 7))
        #expect(!plan.choice.isNow)
    }

    @Test func insideTheUsualNightNapIsBlockedAndBedIsNow() {
        let plan = plan(date(2026, 3, 10, 23, 30), kind: .nap)
        #expect(plan.kind == .sleep)
        #expect(plan.napBlocked != nil)
        #expect(plan.choice.bed == date(2026, 3, 10, 23, 30))
        #expect(plan.choice.wake == date(2026, 3, 11, 7))
    }

    @Test func soonAfterANightItsBackToSleep() {
        let night = PastNight(start: date(2026, 3, 10, 23), end: date(2026, 3, 11, 7), asleep: 7.75 * 3600)
        let plan = plan(date(2026, 3, 11, 7, 30), nights: [night])
        #expect(plan.choice.resleep)
        #expect(plan.choice.bed == date(2026, 3, 11, 7, 30))
    }

    @Test func pastPickedBedMeansNowWhileItsWakeIsAhead() {
        let plan = plan(date(2026, 3, 10, 14), bed: date(2026, 3, 10, 13), wake: date(2026, 3, 10, 16))
        #expect(plan.choice.bed == date(2026, 3, 10, 14))
        #expect(plan.choice.wake == date(2026, 3, 10, 16))
    }

    @Test func napBlockedNearBedOrInTheNightBeforeSleeping() {
        let profile = JetLagProfile()
        #expect(SleepPlan.napBlocked(profile, now: date(2026, 3, 10, 22, 30), slept: true, calendar: gregorian()) != nil)
        #expect(SleepPlan.napBlocked(profile, now: date(2026, 3, 11, 5), slept: false, calendar: gregorian()) != nil)
        #expect(SleepPlan.napBlocked(profile, now: date(2026, 3, 11, 5), slept: true, calendar: gregorian()) == nil)
        #expect(SleepPlan.napBlocked(profile, now: date(2026, 3, 10, 14), slept: false, calendar: gregorian()) == nil)
    }
}

struct MorningLogTests {
    init() { useDefaultCycle() }

    @Test func proposesLastNightAtTheUsualHoursAfterWaking() {
        let advice = napAdvice()
        #expect(MorningLog.proposal(now: date(2026, 3, 11, 8), naps: [], health: [], advice: advice)
            .map { [$0.start, $0.end] } == [date(2026, 3, 10, 23), date(2026, 3, 11, 7)])
        #expect(MorningLog.proposal(now: date(2026, 3, 11, 6), naps: [], health: [], advice: advice) == nil)
        #expect(MorningLog.proposal(now: date(2026, 3, 11, 13), naps: [], health: [], advice: advice) == nil)
    }

    @Test func noProposalWhenANightIsAlreadyKnown() {
        let advice = napAdvice()
        let now = date(2026, 3, 11, 8)
        let health = PastNight(start: date(2026, 3, 10, 23, 30), end: date(2026, 3, 11, 6, 50), asleep: 7 * 3600)
        let logged = Nap(start: date(2026, 3, 10, 23), end: date(2026, 3, 11, 6, 40))
        #expect(MorningLog.proposal(now: now, naps: [], health: [health], advice: advice) == nil)
        #expect(MorningLog.proposal(now: now, naps: [logged], health: [], advice: advice) == nil)
    }

    @Test func usualHoursAreTheMediansAcrossMidnight() {
        let beds = [(23, 50), (0, 10), (23, 40), (0, 20), (23, 55), (0, 5), (0, 0)]
        let nights = beds.enumerated().map { i, bed in
            let start = date(2026, 3, 10 + i + (bed.0 == 0 ? 1 : 0), bed.0, bed.1)
            return PastNight(start: start, end: date(2026, 3, 11 + i, 7, 10), asleep: 7 * 3600)
        }
        let usual = MorningLog.usualHours(from: nights, calendar: gregorian())
        #expect(usual?.bed == 0 && usual?.wake == 7 * 60 + 10)
        #expect(MorningLog.usualHours(from: Array(nights.prefix(6)), calendar: gregorian()) == nil)
    }
}

struct NightScheduleTests {
    @Test func minutesUntilTheLastHourThenSeconds() {
        let schedule = NightSchedule(active: ActiveNap(start: date(2026, 3, 10, 22), minutes: 8 * 60))
        #expect(schedule.nextEntry(after: date(2026, 3, 10, 20, 0, 30)) == date(2026, 3, 10, 20, 1))
        #expect(schedule.nextEntry(after: date(2026, 3, 10, 20, 59, 30)) == date(2026, 3, 10, 21))
        #expect(schedule.nextEntry(after: date(2026, 3, 10, 21, 30)) == date(2026, 3, 10, 21, 30, 1))
        #expect(schedule.nextEntry(after: date(2026, 3, 10, 23)) == date(2026, 3, 10, 23, 1))
        #expect(schedule.nextEntry(after: date(2026, 3, 11, 5, 30)) == date(2026, 3, 11, 5, 30, 1))
    }

    @Test func alarmOffStaysOnMinutes() {
        var nap = ActiveNap(start: date(2026, 3, 10, 22), minutes: 8 * 60)
        nap.alarmOff = true
        #expect(NightSchedule(active: nap).nextEntry(after: date(2026, 3, 11, 5, 30)) == date(2026, 3, 11, 5, 31))
        #expect(NightSchedule(active: nil).nextEntry(after: date(2026, 3, 11, 5, 30, 10)) == date(2026, 3, 11, 5, 31))
    }
}

struct SleepRingTests {
    init() { useDefaultCycle() }

    @Test func hoursSitAtTheirRealOffsetOnAClockChangeNight() {
        let offsets = SleepRing.hourOffsets(from: date(2026, 3, 7, 22, in: newYork), calendar: gregorian(newYork))
        #expect(offsets[23] == 60)
        #expect(offsets[6] == 7 * 60)
        #expect(SleepRing.hourOffsets(from: date(2026, 3, 10, 22), calendar: gregorian())[6] == 8 * 60)
    }

    @Test func snapAndDetents() {
        #expect(SleepRing.snap(date(2026, 3, 10, 14, 4)) == date(2026, 3, 10, 14))
        #expect(SleepRing.snap(date(2026, 3, 10, 14, 6)) == date(2026, 3, 10, 14, 10))
        #expect(SleepRing.detent(near: 108, fallAsleep: 15) == 105)
        #expect(SleepRing.detent(near: 130, fallAsleep: 15) == nil)
    }
}

struct NightRuleTests {
    init() { useDefaultCycle() }

    @Test func underThreeHoursIsANapUnlessGoingBackToSleep() {
        let start = date(2026, 3, 10, 22)
        #expect(ActiveNap(start: start, minutes: 120).isNap)
        #expect(!ActiveNap(start: start, minutes: 180).isNap)
        #expect(!ActiveNap(start: start, minutes: 60, resleep: true).isNap)
        let choice = WakeChoice(now: start, bed: start, wake: date(2026, 3, 11))
        #expect(choice.isNap && choice.button.hasPrefix("Nap now"))
        #expect(Nap(start: start, end: date(2026, 3, 11)).isNight == false)
    }

    @Test func napAfterMidnightIsJudgedAgainstThatNightsBed() {
        let advice = napAdvice(bed: 90)
        #expect(advice.nextBed(after: date(2026, 3, 11, 1)) == date(2026, 3, 11, 1, 30))
        #expect(advice.tonight(start: date(2026, 3, 11, 1), minutes: 20) == .high)
    }
}

struct HealthNightTests {
    @Test func inBedFillsOnlyNightsWithNoAsleepData() {
        let asleep = [(date(2026, 3, 10, 23), date(2026, 3, 11, 3)), (date(2026, 3, 11, 3, 30), date(2026, 3, 11, 7))]
        let inBed = [(date(2026, 3, 10, 22, 50), date(2026, 3, 11, 7, 10)), (date(2026, 3, 8, 23), date(2026, 3, 9, 7))]
        let intervals = PastNights.intervals(asleep: asleep, inBed: inBed)
        #expect(intervals.map(\.0) == [date(2026, 3, 8, 23), date(2026, 3, 10, 23), date(2026, 3, 11, 3, 30)])
    }

    @Test func cycleIsTheMedianGapBetweenRemSpells() {
        let start = date(2026, 3, 10, 23)
        var rem = (0..<11).map { i in
            let at = start.addingTimeInterval(Double(i) * 95 * 60)
            return (at, at.addingTimeInterval(10 * 60))
        }
        rem.append((start.addingTimeInterval(15 * 60), start.addingTimeInterval(20 * 60)))
        let estimate = PastNights.cycleEstimate(rem: rem)
        #expect(estimate?.minutes == 95 && estimate?.count == 10)
        #expect(PastNights.cycleEstimate(rem: Array(rem.prefix(5))) == nil)
    }
}

struct SleepHistoryLogicTests {
    @Test func streakBreaksOnAMissingDayAndCountsADayOnce() {
        let night = { (day: Int, hour: Int) in
            PastNight(start: date(2026, 3, day - 1, 23), end: date(2026, 3, day, hour), asleep: 7 * 3600)
        }
        #expect(SleepTrend.wakeStreak([night(12, 7), night(10, 7)], usualWake: 420, calendar: gregorian()) == 1)
        #expect(SleepTrend.wakeStreak([night(12, 7), night(12, 3), night(11, 7)], usualWake: 420, calendar: gregorian()) == 2)
    }

    @Test func energyMeanIsTheLastTwoWeeks() {
        let now = date(2026, 3, 30, 12)
        let old = Nap(start: date(2026, 3, 1, 14), end: date(2026, 3, 1, 14, 20), energy: 1)
        let recent = Nap(start: date(2026, 3, 29, 14), end: date(2026, 3, 29, 14, 20), energy: 5)
        #expect(EnergyChart.mean(EnergyChart.rated([old, recent]), now: now) == 5)
        #expect(EnergyChart.mean(EnergyChart.rated([old]), now: now) == nil)
    }
}
