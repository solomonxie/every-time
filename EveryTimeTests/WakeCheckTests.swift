import Foundation
import Testing
@testable import EveryTime

struct WakeCheckTests {
    init() { useDefaultCycle() }

    private let start = date(2026, 3, 10, 23)

    @Test func firstMinutesDontCount() {
        let check = WakeCheck(start: start, now: date(2026, 3, 10, 23, 20))
        #expect(check.isFirstMinutes)
        #expect(!check.isAtCycleEnd)
        #expect(check.cycles == 0)
    }

    @Test func atACycleEnd() {
        // Asleep 23:15; cycles end 00:45, 02:15, 03:45.
        let check = WakeCheck(start: start, now: date(2026, 3, 11, 2, 20))
        #expect(check.isAtCycleEnd)
        #expect(check.cycles == 2)
        #expect(check.detail.hasPrefix("2 cycles"))
        let justBefore = WakeCheck(start: start, now: date(2026, 3, 11, 3, 35))
        #expect(justBefore.isAtCycleEnd)
        #expect(justBefore.detail.hasPrefix("3 cycles"))
    }

    @Test func midCycle() {
        let check = WakeCheck(start: start, now: date(2026, 3, 11, 3))
        #expect(!check.isAtCycleEnd)
        #expect(check.cycles == 2)
        #expect(check.nextCycleEnd == date(2026, 3, 11, 3, 45))
        #expect(check.detail == "2 cycles done · 45 min to the next end, ~\(SleepNow.clock(date(2026, 3, 11, 3, 45)))")
    }
}

struct ResleepTests {
    init() { useDefaultCycle() }

    @Test func goingBackToSleepEndsACycleSooner() {
        let start = date(2026, 3, 11, 6)
        let nap = ActiveNap(start: start, minutes: 95, resleep: true)
        let check = WakeCheck(start: start, now: nap.alarm, latency: nap.fallAsleep)
        #expect(check.cycles == 1)
        #expect(check.isAtCycleEnd)
        #expect(ActiveNap(start: start, minutes: 95).fallAsleep == 15 * 60)
    }

    @Test func everyCycleEndIsGoodWhenGoingBackToSleep() {
        for cycles in 1...3 {
            let length = (5 + Double(cycles) * 90) * 60
            #expect(WakeFit.of(length: length, isNap: false, resleep: true) == .good)
            #expect(WakeFit.of(length: length, isNap: false) != .good)
        }
        #expect(WakeFit.of(length: (5 + 45) * 60, isNap: false, resleep: true) == .poor)
    }

    @Test func soonAfterANightOnly() {
        let night = PastNight(start: date(2026, 3, 11, 1), end: date(2026, 3, 11, 6, 30), asleep: 5 * 3600)
        #expect(night.isResleep(at: date(2026, 3, 11, 7, 30)))
        #expect(!night.isResleep(at: date(2026, 3, 11, 8, 31)))
        #expect(!night.isResleep(at: date(2026, 3, 11, 6)))
    }

    @Test func picksTheCyclesThatMakeUpLastNight() {
        let start = date(2026, 3, 11, 7, 30)
        let now = SleepNow(advice: napAdvice(), start: start, resleepShortfall: 2 * 3600)
        #expect(now.options.count == 4)
        #expect(now.options.allSatisfy { $0.level == .low })
        #expect(now.pick?.kind == .night(cycles: 2, wake: date(2026, 3, 11, 10, 35)))
        #expect(SleepNow(advice: napAdvice(), start: start, resleepShortfall: 0).pick?.time == date(2026, 3, 11, 9, 5))
    }

    @Test func oneCycleIsASleepNotANap() {
        let now = date(2026, 3, 11, 7, 30)
        let choice = WakeChoice(now: now, bed: now, wake: date(2026, 3, 11, 9, 5), resleep: true)
        #expect(!choice.isNap)
        #expect(choice.fit == .good)
        #expect(choice.cycles == 1)
    }
}

struct SleepScoreTests {
    init() { useDefaultCycle() }

    @Test func fullNightBetweenCyclesScoresHigh() {
        #expect(SleepScore.score(asleep: 7.5 * 3600, need: 8 * 3600, energy: 5) == 96)
        #expect(SleepScore.score(asleep: 7.5 * 3600, need: 8 * 3600) == 88)
    }

    @Test func shortMidCycleNightScoresLow() {
        #expect(SleepScore.score(asleep: 4 * 3600, need: 8 * 3600, energy: 2) == 43)
        #expect(SleepScore.level(43) == .high)
        #expect(SleepScore.level(70) == .some)
    }
}

struct CaffeineTests {
    @Test func cutoffIsNineHoursBeforeBed() {
        #expect(Caffeine.cutoff(bed: date(2026, 3, 10, 23)) == date(2026, 3, 10, 14))
    }
}

struct PastNightMergeTests {
    init() { useDefaultCycle() }

    @Test func loggedStretchesJoinAndBeatHealth() {
        let logged = [
            Nap(start: date(2026, 3, 10, 23), end: date(2026, 3, 11, 3), energy: 2),
            Nap(start: date(2026, 3, 11, 3, 10), end: date(2026, 3, 11, 6, 30), energy: 4),
            Nap(start: date(2026, 3, 11, 14), end: date(2026, 3, 11, 14, 20), energy: 5),
        ]
        let health = [
            PastNight(start: date(2026, 3, 10, 23, 5), end: date(2026, 3, 11, 6, 20), asleep: 7 * 3600),
            PastNight(start: date(2026, 3, 9, 23), end: date(2026, 3, 10, 7), asleep: 7.5 * 3600),
        ]
        let nights = PastNight.merged(logged: logged, health: health, calendar: gregorian())
        #expect(nights.map(\.start) == [date(2026, 3, 10, 23), date(2026, 3, 9, 23)])
        #expect(nights[0].asleep == 7 * 3600 + 5 * 60)
        #expect(nights[0].energy == 4)
    }
}


struct SleepCycleTests {
    init() { useDefaultCycle() }

    private func wake(_ minutes: Int, natural: Bool? = true) -> Nap {
        let start = date(2026, 3, 10, 23)
        return Nap(start: start, end: start.addingTimeInterval(Double(minutes) * 60), natural: natural)
    }

    @Test func learnsTheLengthThatPutsNaturalWakesOnCycleEnds() {
        // 15 min to fall asleep, then 2, 3, 1, 4 and 2 cycles of ~100 min.
        let naps = [wake(215), wake(318), wake(113), wake(412), wake(217), wake(300, natural: false), wake(450, natural: nil)]
        let learned = SleepCycle.learned(from: naps, fallAsleep: 15)
        #expect(learned?.minutes == 100)
        #expect(learned?.count == 5)
    }

    @Test func backToSleepFallsAsleepQuickly() {
        let night = Nap(start: date(2026, 3, 10, 23), end: date(2026, 3, 11, 5), natural: true)
        let soon = Nap(start: date(2026, 3, 11, 6), end: date(2026, 3, 11, 7, 45), natural: true)
        let later = Nap(start: date(2026, 3, 11, 9), end: date(2026, 3, 11, 10, 45), natural: true)
        let flagged = Nap(start: date(2026, 3, 11, 13), end: date(2026, 3, 11, 14, 45), natural: true, resleep: true)
        #expect(soon.isResleep(among: [night, soon]))
        #expect(!later.isResleep(among: [night, later]))
        #expect(flagged.isResleep(among: [flagged]))
        #expect(!night.isResleep(among: [night, soon]))
        #expect(SleepCycle.learned(from: Array(repeating: soon, count: 5) + [night], fallAsleep: 15, minCount: 1)?.minutes == 100)
    }

    @Test func needsFiveNaturalWakes() {
        #expect(SleepCycle.learned(from: [wake(215), wake(318), wake(113), wake(412)], fallAsleep: 15) == nil)
    }

    @Test func manualBeatsLearned() {
        var cycle = SleepCycle()
        cycle.learnedMinutes = 100
        #expect(cycle.minutes == 100)
        cycle.manualMinutes = 85
        #expect(cycle.minutes == 85)
    }
}
