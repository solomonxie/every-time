import Foundation
import Testing
@testable import EveryTime

struct SleepSuggestionTests {
    @Test func bedtimesCountBackWholeCyclesPlusFallingAsleep() {
        let bedtimes = SleepSuggestion.bedtimes(wakingAt: date(2026, 3, 11, 7))
        #expect(bedtimes.map(\.cycles) == [6, 5, 4, 3])
        #expect(bedtimes.map(\.time) == [date(2026, 3, 10, 21, 45), date(2026, 3, 10, 23, 15),
                                         date(2026, 3, 11, 0, 45), date(2026, 3, 11, 2, 15)])
        #expect(bedtimes.map(\.isRecommended) == [true, true, false, false])
        #expect(bedtimes.map(\.hours) == [9, 7.5, 6, 4.5])
    }

    @Test func wakeTimesCountForwardFromBed() {
        let wakes = SleepSuggestion.wakeTimes(goingToBedAt: date(2026, 3, 10, 23))
        #expect(wakes.map(\.time) == [date(2026, 3, 11, 8, 15), date(2026, 3, 11, 6, 45),
                                      date(2026, 3, 11, 5, 15), date(2026, 3, 11, 3, 45)])
    }

    @Test func nextOccurrenceIsStrictlyAfterNow() {
        let calendar = gregorian()
        let wake = 7 * 60 + 30
        #expect(SleepSuggestion.nextOccurrence(ofMinutes: wake, after: date(2026, 3, 10, 6), calendar: calendar)
            == date(2026, 3, 10, 7, 30))
        #expect(SleepSuggestion.nextOccurrence(ofMinutes: wake, after: date(2026, 3, 10, 7, 30), calendar: calendar)
            == date(2026, 3, 11, 7, 30))
        #expect(SleepSuggestion.nextOccurrence(ofMinutes: wake, after: date(2026, 3, 10, 8), calendar: calendar)
            == date(2026, 3, 11, 7, 30))
    }

    @Test func fitCountsCyclesAndFlagsMidCycleWakes() {
        let fit = { (minutes: Int) in
            let fit = SleepSuggestion.fit(minutesInBed: minutes)
            return "\(fit.cycles) \(fit.isBetweenCycles ? "between" : "mid")"
        }
        #expect(fit(7 * 60 + 45) == "5 between")
        #expect(fit(8 * 60) == "5 between")
        #expect(fit(7 * 60 + 30) == "5 between")
        #expect(fit(8 * 60 + 30) == "5 mid")
        #expect(fit(20) == "0 mid")
    }

    @Test func dialStopsAtNightLimitsInsteadOfWrapping() {
        let night = NightDial.Hours(bed: 23 * 60, wake: 7 * 60)
        #expect(night.length == 8 * 60)
        #expect(night.moving(bed: 22 * 60) == NightDial.Hours(bed: 22 * 60, wake: 7 * 60))
        #expect(night.moving(bed: 5 * 60) == NightDial.Hours(bed: 4 * 60, wake: 7 * 60))
        #expect(night.moving(bed: 16 * 60) == NightDial.Hours(bed: 17 * 60, wake: 7 * 60))
        #expect(night.moving(wake: 23 * 60 + 30) == NightDial.Hours(bed: 23 * 60, wake: 2 * 60))
        #expect(night.shifted(by: 90) == NightDial.Hours(bed: 30, wake: 8 * 60 + 30))
    }
}
