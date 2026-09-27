import Foundation
import Testing
@testable import EveryTime

struct AnniversaryTests {
    private let calendar = gregorian()

    private func parts(_ elapsed: Anniversary.Elapsed) -> String {
        elapsed.parts.map { "\($0.value) \($0.unit)" }.joined(separator: " ")
    }

    @Test func elapsedUnits() {
        let years = Anniversary.elapsed(since: date(2020, 1, 1), to: date(2024, 4, 2, 9), calendar: calendar)
        #expect(years.days == 1553)
        #expect(parts(years) == "4 years 92 days")
        #expect(parts(Anniversary.elapsed(since: date(2026, 1, 10), to: date(2026, 4, 15), calendar: calendar)) == "3 months 5 days")
        #expect(parts(Anniversary.elapsed(since: date(2025, 1, 10), to: date(2026, 1, 11), calendar: calendar)) == "1 year 1 day")
        #expect(parts(Anniversary.elapsed(since: date(2026, 1, 10), to: date(2026, 1, 11), calendar: calendar)) == "1 day")
    }

    @Test func futureIsNegativeDays() {
        let elapsed = Anniversary.elapsed(since: date(2026, 2, 1), to: date(2026, 1, 20), calendar: calendar)
        #expect(elapsed.days == -12)
        #expect(parts(elapsed) == "12 days")
    }

    @Test func leapDayFallsOnFeb28() {
        let leapDay = date(2024, 2, 29)
        #expect(Anniversary.occurrence(of: leapDay, in: 2025, calendar: calendar) == date(2025, 2, 28))
        #expect(Anniversary.occurrence(of: leapDay, in: 2028, calendar: calendar) == date(2028, 2, 29))
    }

    @Test func nextAnniversary() {
        let event = date(2000, 5, 10)
        #expect(Anniversary.next(of: event, from: date(2026, 5, 10, 20), calendar: calendar) == date(2026, 5, 10))
        #expect(Anniversary.next(of: event, from: date(2026, 5, 11), calendar: calendar) == date(2027, 5, 10))
        #expect(Anniversary.next(of: date(2026, 5, 10), from: date(2026, 1, 1), calendar: calendar) == date(2027, 5, 10))
        #expect(Anniversary.years(at: date(2026, 5, 10), since: event, calendar: calendar) == 26)
    }

    @Test func countdownUnits() {
        let now = date(2026, 1, 1)
        func countdown(_ to: Date, hasTime: Bool = false) -> Anniversary.Countdown {
            Anniversary.countdown(to: to, from: now, hasTime: hasTime, calendar: calendar)
        }
        #expect(countdown(now.addingTimeInterval(90), hasTime: true).value == 2)
        #expect(countdown(now.addingTimeInterval(30 * 60), hasTime: true).unit == "minutes")
        #expect(countdown(now.addingTimeInterval(3600), hasTime: true) == .init(value: 1, unit: "hour", detail: "1h 0m"))
        #expect(countdown(now.addingTimeInterval(47 * 3600 + 59 * 60), hasTime: true) == .init(value: 47, unit: "hours", detail: "47h 59m"))
        #expect(countdown(date(2026, 1, 2)) == .init(value: 1, unit: "day", detail: "tomorrow"))
        #expect(countdown(date(2026, 1, 14)).unit == "days")
        #expect(countdown(date(2026, 1, 15)) == .init(value: 2, unit: "weeks", detail: "2 wk 0 d · 14 days"))
        #expect(countdown(date(2026, 4, 11)) == .init(value: 3, unit: "months", detail: "3 mo 10 d · 100 days"))
        #expect(countdown(date(2028, 3, 11)) == .init(value: 2, unit: "years", detail: "2 y 2 mo · 800 days"))
    }

    @Test func pastCountsAsNow() {
        let now = date(2026, 1, 1, 12)
        #expect(Anniversary.countdown(to: now.addingTimeInterval(-60), from: now, hasTime: true, calendar: calendar).value == 0)
    }

    @Test(arguments: [(1, "1st"), (2, "2nd"), (3, "3rd"), (4, "4th"), (11, "11th"), (12, "12th"), (13, "13th"),
                      (21, "21st"), (22, "22nd"), (101, "101st"), (111, "111th"), (112, "112th")])
    func ordinal(_ n: Int, _ expected: String) {
        #expect(Anniversary.ordinal(n) == expected)
    }

    @Test func phrases() {
        #expect(Anniversary.phrase(.birthday, years: 34, name: "Me", isToday: false) == "Turns 34")
        #expect(Anniversary.phrase(.birthday, years: 34, name: "Me", isToday: true) == "34th birthday 🎂")
        #expect(Anniversary.phrase(.wedding, years: 5, name: "", isToday: true) == "5th wedding anniversary")
        #expect(Anniversary.phrase(.memorial, years: 1, name: "", isToday: false) == "1 year since")
        #expect(Anniversary.phrase(.milestone, years: 5, name: "Moved to SF", isToday: false) == "5 years since Moved to SF")
        #expect(Anniversary.phraseIncludesName(.other) && !Anniversary.phraseIncludesName(.birthday))
    }
}
