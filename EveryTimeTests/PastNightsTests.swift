import Foundation
import Testing
@testable import EveryTime

struct PastNightsTests {
    @Test func overlappingSourcesCountOnce() {
        let merged = PastNights.merge([
            (date(2026, 9, 27, 23), date(2026, 9, 28, 3)),
            (date(2026, 9, 28, 1), date(2026, 9, 28, 7)),
        ])
        #expect(merged.count == 1)
        #expect(merged[0].1 == date(2026, 9, 28, 7))
    }

    @Test func wakingBrieflyStaysOneNightAndNapsAreDropped() {
        let nights = PastNights.nights(from: [
            (date(2026, 9, 26, 23), date(2026, 9, 27, 3)),
            (date(2026, 9, 27, 3, 30), date(2026, 9, 27, 7)),
            (date(2026, 9, 27, 14), date(2026, 9, 27, 14, 30)),
            (date(2026, 9, 27, 23), date(2026, 9, 28, 6)),
        ], calendar: gregorian())
        #expect(nights.count == 2)
        #expect(nights[0].end == date(2026, 9, 28, 6))
        #expect(nights[1].start == date(2026, 9, 26, 23))
        #expect(nights[1].asleep == 7.5 * 3600)
    }
}
