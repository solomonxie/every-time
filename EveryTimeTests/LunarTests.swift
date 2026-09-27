import Foundation
import Testing
@testable import EveryTime

struct LunarTests {
    private let lunar = Lunar.calendar(timeZone: shanghai)

    @Test func convertsGregorianToLunar() {
        #expect(Lunar.date(of: date(2026, 2, 17, 12), calendar: lunar) == LunarDate(month: 1, day: 1))
        #expect(Lunar.date(of: date(2026, 9, 25), calendar: lunar) == LunarDate(month: 8, day: 15))
        #expect(Lunar.date(of: date(2025, 7, 25), calendar: lunar) == LunarDate(month: 6, day: 1, isLeapMonth: true))
    }

    @Test func chineseNames() {
        #expect(LunarDate(month: 1, day: 1).chinese == "正月初一")
        #expect(LunarDate(month: 8, day: 15).chinese == "八月十五")
        #expect(LunarDate(month: 11, day: 10).chinese == "十一月初十")
        #expect(LunarDate(month: 12, day: 20).chinese == "十二月二十")
        #expect(LunarDate(month: 6, day: 21, isLeapMonth: true).chinese == "闰六月廿一")
        #expect(LunarDate(month: 10, day: 30).chinese == "十月三十")
        #expect(LunarDate(month: 3, day: 5).numeric == "Lunar 3/5")
    }

    @Test func yearlyOccurrences() {
        let dates = Lunar.occurrences(month: 8, day: 15, repeat: .yearly, count: 3, from: date(2026, 9, 1), calendar: lunar)
        #expect(dates == [date(2026, 9, 25), date(2027, 9, 15), date(2028, 10, 3)])
    }

    @Test func todayCountsButYesterdayDoesNot() {
        #expect(Lunar.nextOccurrence(month: 8, day: 15, from: date(2026, 9, 25, 18), calendar: lunar) == date(2026, 9, 25))
        #expect(Lunar.nextOccurrence(month: 8, day: 15, from: date(2026, 9, 26), calendar: lunar) == date(2027, 9, 15))
    }

    @Test func lunarYearStraddlesGregorianNewYear() {
        #expect(Lunar.nextOccurrence(month: 1, day: 1, from: date(2026, 2, 10), calendar: lunar) == date(2026, 2, 17))
        #expect(Lunar.nextOccurrence(month: 12, day: 1, from: date(2026, 1, 5), calendar: lunar) == date(2026, 1, 19))
    }

    @Test func dayThirtyClampsToShortMonth() {
        #expect(Lunar.nextOccurrence(month: 12, day: 30, from: date(2026, 1, 5), calendar: lunar) == date(2026, 2, 16))
    }

    @Test func monthlyOccurrences() {
        let dates = Lunar.occurrences(month: 1, day: 1, repeat: .monthly, count: 3, from: date(2026, 2, 18), calendar: lunar)
        #expect(dates.count == 3)
        #expect(dates.map { Lunar.date(of: $0, calendar: lunar).day } == [1, 1, 1])
        #expect(dates.first.map { $0 > date(2026, 2, 18) } == true)
    }

    @Test func onceIsAnchoredAtCreation() {
        let event = LunarEvent(name: "Once", month: 8, day: 15, repeat: .never, created: date(2026, 9, 1))
        #expect(Lunar.occurrences(of: event, from: date(2027, 1, 1), calendar: lunar) == [date(2026, 9, 25)])
        let yearly = LunarEvent(name: "Yearly", month: 8, day: 15, created: date(2020, 1, 1))
        #expect(Lunar.occurrences(of: yearly, from: date(2026, 9, 1), calendar: lunar).count == LunarRepeat.yearly.exportCount)
    }

    @Test func daysUntil() {
        #expect(Lunar.daysUntil(date(2026, 9, 25), from: date(2026, 9, 20, 23), calendar: lunar) == 5)
        #expect(Lunar.daysUntil(date(2026, 9, 25, 1), from: date(2026, 9, 25, 23), calendar: lunar) == 0)
    }

    @Test func decodesOlderEventsWithDefaults() throws {
        let json = Data(#"{"name":"Mom","month":3,"day":8}"#.utf8)
        let event = try JSONDecoder().decode(LunarEvent.self, from: json)
        #expect(event.repeat == .yearly)
        #expect(event.calendarEventIDs.isEmpty)
    }
}
