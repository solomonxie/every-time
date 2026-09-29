import Foundation
import Testing
@testable import EveryTime

struct ActivityLogTests {
    private func log(_ marks: [(Date, String?)]) -> ActivityLog {
        ActivityLog(marks: marks.map { ActivityMark(time: $0.0, tag: $0.1) }, calendar: gregorian())
    }

    @Test func eachMarkRunsUntilTheNextAndTheLastStaysOpen() {
        let spans = log([(date(2026, 9, 28, 9), "work"), (date(2026, 9, 28, 8), "eat")])
            .spans(at: date(2026, 9, 28, 10))
        #expect(spans.map(\.tag) == ["eat", "work"])
        #expect(spans[0].duration == 3600)
        #expect(spans[1].isOpen && spans[1].duration == 3600)
    }

    @Test func todayCountsOnlyTheHoursAfterMidnight() {
        let log = log([(date(2026, 9, 27, 23), "sleep"), (date(2026, 9, 28, 7), "wake"), (date(2026, 9, 28, 8), nil)])
        let now = date(2026, 9, 28, 9)
        let totals = log.totals(in: log.today(at: now), at: now)
        #expect(totals.first { $0.tag == "sleep" }?.time == 7 * 3600)
        #expect(totals.first { $0.tag == nil }?.time == 3600)
    }

    @Test func upSinceIsTheEndOfTheNightNotANap() {
        let log = log([
            (date(2026, 9, 27, 23, 30), "sleep"), (date(2026, 9, 28, 7), "wake"),
            (date(2026, 9, 28, 14), "nap"), (date(2026, 9, 28, 14, 20), "wake"),
        ])
        #expect(log.upSince(at: date(2026, 9, 28, 16)) == date(2026, 9, 28, 7))
        #expect(log.nights(at: date(2026, 9, 28, 16)).count == 1)
    }

    @Test func typicalBedtimeAveragesAcrossMidnight() {
        let log = log([
            (date(2026, 9, 26, 23, 30), "sleep"), (date(2026, 9, 27, 7), "wake"),
            (date(2026, 9, 28, 0, 30), "sleep"), (date(2026, 9, 28, 8), "wake"),
        ])
        let typical = log.typical(at: date(2026, 9, 28, 12))
        #expect(typical.nights == 2)
        #expect(typical.bed == 0)
        #expect(typical.wake == 7 * 60 + 30)
        #expect(typical.sleep == 7.5 * 3600)
    }
}
