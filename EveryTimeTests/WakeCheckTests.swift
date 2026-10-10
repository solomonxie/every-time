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

struct SleepScoreTests {
    init() { useDefaultCycle() }

    @Test func fullNightBetweenCyclesScoresHigh() {
        #expect(SleepScore.score(asleep: 7.5 * 3600, usualHours: 8, energy: 5) == 96)
        #expect(SleepScore.score(asleep: 7.5 * 3600, usualHours: 8) == 88)
    }

    @Test func shortMidCycleNightScoresLow() {
        #expect(SleepScore.score(asleep: 4 * 3600, usualHours: 8, energy: 2) == 43)
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
        #expect(nights[0].asleep == 7 * 3600 + 20 * 60)
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
        // 15 min to fall asleep, then 2, 3 and 1 cycles of ~100 min.
        let naps = [wake(215), wake(318), wake(113), wake(300, natural: false), wake(450, natural: nil)]
        let learned = SleepCycle.learned(from: naps, fallAsleep: 15)
        #expect(learned?.minutes == 100)
        #expect(learned?.count == 3)
    }

    @Test func needsThreeNaturalWakes() {
        #expect(SleepCycle.learned(from: [wake(215), wake(318)], fallAsleep: 15) == nil)
    }

    @Test func manualBeatsLearned() {
        var cycle = SleepCycle()
        cycle.learnedMinutes = 100
        #expect(cycle.minutes == 100)
        cycle.manualMinutes = 85
        #expect(cycle.minutes == 85)
    }
}
