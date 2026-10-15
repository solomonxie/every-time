import Foundation
import Testing
@testable import EveryTime

struct WorkLogTests {
    private func work(_ start: Date, _ end: Date?) -> WorkSpan { WorkSpan(kind: .work, start: start, end: end) }

    @Test func nightShiftSplitsAtMidnight() {
        let log = WorkLog(spans: [work(date(2026, 9, 28, 22), date(2026, 9, 29, 6))])
        let days = log.days(at: date(2026, 9, 29, 12), calendar: gregorian())
        #expect(days.map(\.date) == [date(2026, 9, 29), date(2026, 9, 28)])
        #expect(days.map(\.worked) == [6 * 3600, 2 * 3600])
    }

    @Test func deleteDayTrimsNightShift() {
        let shift = work(date(2026, 9, 28, 22), date(2026, 9, 29, 6))
        let now = date(2026, 9, 29, 12)
        var log = WorkLog(spans: [shift])
        log.deleteDay(date(2026, 9, 29), calendar: gregorian())
        let days = log.days(at: now, calendar: gregorian())
        #expect(days.map(\.date) == [date(2026, 9, 28)])
        #expect(days.first?.worked == TimeInterval(2 * 3600))

        var other = WorkLog(spans: [shift])
        other.deleteDay(date(2026, 9, 28), calendar: gregorian())
        #expect(other.days(at: now, calendar: gregorian()).map(\.worked) == [6 * 3600])
    }

    @Test func deleteDayInsideALongSpanSplitsIt() {
        var log = WorkLog(spans: [work(date(2026, 9, 27, 20), date(2026, 9, 29, 4))])
        log.deleteDay(date(2026, 9, 28), calendar: gregorian())
        #expect(log.spans.count == 2)
        #expect(log.days(at: date(2026, 9, 29, 12), calendar: gregorian()).map(\.worked) == [4 * 3600, 4 * 3600])
    }

    @Test func deleteTodayClosesARunningSpanAtMidnight() {
        var log = WorkLog(spans: [work(date(2026, 9, 28, 22), nil)])
        log.deleteDay(date(2026, 9, 29), calendar: gregorian())
        #expect(log.state == .off)
        #expect(log.spans.first?.end == date(2026, 9, 29))
    }

    @Test func dstDaysCountWallClockHours() {
        let calendar = gregorian(newYork)
        let spring = WorkLog(spans: [work(date(2026, 3, 8, in: newYork), date(2026, 3, 9, in: newYork))])
        #expect(spring.days(at: date(2026, 3, 10, in: newYork), calendar: calendar).map(\.worked) == [23 * 3600])
        let fall = WorkLog(spans: [work(date(2026, 11, 1, in: newYork), date(2026, 11, 2, in: newYork))])
        #expect(fall.days(at: date(2026, 11, 3, in: newYork), calendar: calendar).map(\.worked) == [25 * 3600])
    }

    @Test func deleteDayOnDSTNightKeepsNeighbours() {
        let calendar = gregorian(newYork)
        var log = WorkLog(spans: [work(date(2026, 10, 31, 22, in: newYork), date(2026, 11, 2, 2, in: newYork))])
        log.deleteDay(date(2026, 11, 1, 12, in: newYork), calendar: calendar)
        let days = log.days(at: date(2026, 11, 3, in: newYork), calendar: calendar)
        #expect(days.map(\.date) == [date(2026, 11, 2, in: newYork), date(2026, 10, 31, in: newYork)])
        #expect(days.map(\.worked) == [2 * 3600, 2 * 3600])
    }

    @Test func todayCountsOnlyHoursAfterMidnight() {
        let log = WorkLog(spans: [work(date(2026, 9, 28, 22), nil)])
        let today = log.today(at: date(2026, 9, 29, 3), calendar: gregorian())
        #expect(today?.worked == TimeInterval(3 * 3600))
        #expect(today?.isOpen == true)
        #expect(today?.firstIn == date(2026, 9, 29))
    }
}
