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
}
