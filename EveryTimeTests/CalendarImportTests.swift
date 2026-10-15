import Foundation
import Testing
@testable import EveryTime

struct CalendarImportTests {
    private let calendar = gregorian()

    @Test func recurringHitUsesSeriesStart() {
        let firstInWindow = date(1997, 3, 10)
        let resolved = CalendarEventIndex.startDate(occurrence: firstInWindow, seriesStart: date(1980, 3, 10), calendar: calendar)
        #expect(calendar.component(.year, from: resolved) == 1980)
    }

    @Test func placeholderBirthYearKeepsOccurrence() {
        let firstInWindow = date(1997, 3, 10)
        #expect(CalendarEventIndex.startDate(occurrence: firstInWindow, seriesStart: date(1604, 3, 10), calendar: calendar) == firstInWindow)
        #expect(CalendarEventIndex.startDate(occurrence: firstInWindow, seriesStart: nil, calendar: calendar) == firstInWindow)
    }
}
