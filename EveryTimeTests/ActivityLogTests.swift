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

    @Test func oldWakeUpPinsBecomeSleepEndsOrGo() {
        let marks = [(date(2026, 9, 27, 23), "sleep"), (date(2026, 9, 28, 7), "wake"), (date(2026, 9, 28, 9), "work"), (date(2026, 9, 28, 10), "wake")]
            .map { ActivityMark(time: $0.0, tag: $0.1) }
        let kept = ActivityLog.migrateTags(marks + [ActivityMark(time: date(2026, 9, 28, 14), tag: "nap")])
        #expect(kept.map(\.tag) == ["sleep", nil, "work", "sleep"])
    }

    @Test func coffeeIsAMomentAndDoesNotSplitTheDay() {
        let log = log([(date(2026, 9, 28, 9), "work"), (date(2026, 9, 28, 10), "coffee")])
        let spans = log.spans(at: date(2026, 9, 28, 12))
        #expect(spans.map(\.tag) == ["work"])
        #expect(spans[0].isOpen && spans[0].duration == 3 * 3600)
        #expect(log.moments(at: date(2026, 9, 28, 12)).map(\.tag) == ["coffee"])
    }

    @Test func theLastMarkStopsAfterTwelveHours() {
        let spans = log([(date(2026, 9, 27, 15), "work")]).spans(at: date(2026, 9, 28, 10))
        #expect(!spans[0].isOpen)
        #expect(spans[0].end == date(2026, 9, 28, 3))
        #expect(log([(date(2026, 9, 27, 23), "sleep")]).spans(at: date(2026, 9, 28, 7))[0].isOpen)
    }

    @Test func todayCountsOnlyTheHoursAfterMidnight() {
        let log = log([(date(2026, 9, 27, 23), "sleep"), (date(2026, 9, 28, 7), "work"), (date(2026, 9, 28, 8), nil)])
        let now = date(2026, 9, 28, 9)
        let totals = log.totals(in: log.today(at: now), at: now)
        let sleep = totals.first(where: { $0.tag == "sleep" })?.time
        let untagged = totals.first(where: { $0.tag == nil })?.time
        #expect(sleep == TimeInterval(7 * 3600))
        #expect(untagged == TimeInterval(3600))
    }

    @Test func upSinceIsTheEndOfTheNightNotANap() {
        let log = log([
            (date(2026, 9, 27, 23, 30), "sleep"), (date(2026, 9, 28, 7), nil),
            (date(2026, 9, 28, 14), "sleep"), (date(2026, 9, 28, 14, 20), nil),
        ])
        #expect(log.upSince(at: date(2026, 9, 28, 16)) == date(2026, 9, 28, 7))
        #expect(log.nights(at: date(2026, 9, 28, 16)).count == 1)
        #expect(log.spans(at: date(2026, 9, 28, 16))[2].activity.title == "Nap")
    }

    @Test func typicalBedtimeAveragesAcrossMidnight() {
        let log = log([
            (date(2026, 9, 26, 23, 30), "sleep"), (date(2026, 9, 27, 7), nil),
            (date(2026, 9, 28, 0, 30), "sleep"), (date(2026, 9, 28, 8), nil),
        ])
        let typical = log.typical(at: date(2026, 9, 28, 12))
        #expect(typical.nights == 2)
        #expect(typical.bed == 0)
        #expect(typical.wake == 7 * 60 + 30)
        #expect(typical.sleep == 7.5 * 3600)
    }
}
