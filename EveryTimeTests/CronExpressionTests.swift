import Foundation
import Testing
@testable import EveryTime

struct CronExpressionTests {
    private let utc = TimeZone(identifier: "UTC")!

    private func utcDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        date(year, month, day, hour, minute, in: utc)
    }

    @Test func parsesListsRangesStepsAndNames() throws {
        let cron = try CronExpression("*/15 9-17/4 1,15 JAN-mar MON-FRI")
        #expect(cron.values(.minute) == [0, 15, 30, 45])
        #expect(cron.values(.hour) == [9, 13, 17])
        #expect(cron.values(.dayOfMonth) == [1, 15])
        #expect(cron.values(.month) == [1, 2, 3])
        #expect(cron.values(.dayOfWeek) == [1, 2, 3, 4, 5])
        #expect(cron.isDayOfMonthRestricted && cron.isDayOfWeekRestricted)
    }

    @Test func stepFromValueRunsToFieldEnd() throws {
        #expect(try CronExpression("5/20 * * * *").values(.minute) == [5, 25, 45])
    }

    @Test func sundayIsZeroOrSeven() throws {
        #expect(try CronExpression("0 0 * * 7").values(.dayOfWeek) == [0])
        #expect(try CronExpression("0 0 * * *").values(.dayOfWeek) == Set(0...6))
    }

    @Test func macros() throws {
        #expect(try CronExpression("@daily") == CronExpression("0 0 * * *"))
        #expect(try CronExpression(" @WEEKLY ") == CronExpression("0 0 * * 0"))
        #expect(try CronExpression("@yearly") == CronExpression("@annually"))
    }

    @Test(arguments: [
        ("", CronError.empty),
        ("@often", .unknownMacro("@often")),
        ("* * *", .fieldCount(3)),
        ("* * * * * *", .fieldCount(6)),
        ("60 * * * *", .outOfRange(60, field: .minute)),
        ("* 24 * * *", .outOfRange(24, field: .hour)),
        ("* * 0 * *", .outOfRange(0, field: .dayOfMonth)),
        ("*/0 * * * *", .invalidStep("0", field: .minute)),
        ("*/x * * * *", .invalidStep("x", field: .minute)),
        ("5-1 * * * *", .reversedRange("5-1", field: .minute)),
        ("x * * * *", .invalidValue("x", field: .minute)),
        ("1,,2 * * * *", .invalidValue("", field: .minute)),
        ("* * * FOO *", .invalidValue("FOO", field: .month)),
        ("1/2/3 * * * *", .invalidValue("1/2/3", field: .minute)),
    ])
    func rejects(_ text: String, _ error: CronError) {
        #expect(throws: error) { try CronExpression(text) }
    }

    @Test func dayOfMonthOrDayOfWeekWhenBothRestricted() throws {
        let calendar = gregorian(utc)
        let either = try CronExpression("0 0 13 * 5")
        #expect(either.matchesDay(utcDate(2026, 9, 25), calendar: calendar))
        #expect(either.matchesDay(utcDate(2026, 10, 13), calendar: calendar))
        #expect(!either.matchesDay(utcDate(2026, 9, 24), calendar: calendar))
        #expect(!(try CronExpression("0 0 13 * *")).matchesDay(utcDate(2026, 9, 25), calendar: calendar))
        #expect(!(try CronExpression("0 0 * 2 *")).matchesDay(utcDate(2026, 9, 25), calendar: calendar))
    }

    @Test func weekdayRuns() throws {
        let runs = try CronExpression("30 9 * * 1-5").nextRuns(after: utcDate(2026, 9, 25, 10), count: 3, calendar: gregorian(utc))
        #expect(runs == [utcDate(2026, 9, 28, 9, 30), utcDate(2026, 9, 29, 9, 30), utcDate(2026, 9, 30, 9, 30)])
    }

    @Test func runsAreStrictlyAfterStart() throws {
        let runs = try CronExpression("@daily").nextRuns(after: utcDate(2026, 1, 1), count: 1, calendar: gregorian(utc))
        #expect(runs == [utcDate(2026, 1, 2)])
    }

    @Test func sameDayRunsInOrder() throws {
        let runs = try CronExpression("0,30 8,9 * * *").nextRuns(after: utcDate(2026, 1, 1, 8, 10), count: 3, calendar: gregorian(utc))
        #expect(runs == [utcDate(2026, 1, 1, 8, 30), utcDate(2026, 1, 1, 9), utcDate(2026, 1, 1, 9, 30)])
    }

    @Test func leapDayOnly() throws {
        let runs = try CronExpression("0 12 29 2 *").nextRuns(after: utcDate(2026, 1, 1), count: 2, calendar: gregorian(utc))
        #expect(runs == [utcDate(2028, 2, 29, 12), utcDate(2032, 2, 29, 12)])
    }

    @Test func skipsTimesLostToDST() throws {
        let newYork = TimeZone(identifier: "America/New_York")!
        let runs = try CronExpression("30 2 * * *").nextRuns(after: date(2026, 3, 7, 12, in: newYork), count: 2, calendar: gregorian(newYork))
        #expect(runs == [date(2026, 3, 9, 2, 30, in: newYork), date(2026, 3, 10, 2, 30, in: newYork)])
    }

    @Test func impossibleDateNeverRuns() throws {
        #expect(try CronExpression("0 0 31 2 *").nextRuns(after: utcDate(2026, 1, 1), calendar: gregorian(utc)).isEmpty)
    }

    @Test(arguments: [
        ("* * * * *", "Every minute"),
        ("*/15 * * * *", "Every 15 minutes"),
        ("5 * * * *", "Every hour at :05"),
        ("0 9-17 * * *", "At :00, 9–17h"),
        ("*/10 */2 * * *", "Every 10 minutes, every 2 hours"),
    ])
    func summary(_ text: String, _ expected: String) throws {
        #expect(try CronExpression(text).summary == expected)
    }

    @Test func summaryDays() throws {
        #expect(try CronExpression("0 0 1,15 * *").summary.hasSuffix(", on day 1, 15"))
        #expect(try CronExpression("0 0 * * *").summary.hasSuffix(", every day"))
        #expect(try CronExpression("0 0 */2 * *").summary.hasSuffix(", every 2 days"))
    }
}
