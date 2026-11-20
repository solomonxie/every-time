import Foundation
import Testing
@testable import EveryTime

struct MovementBlockTests {
    private let calendar = gregorian()

    private func moves(_ times: [(Int, Int)]) -> [LaborEvent] {
        times.map { LaborEvent(kind: .moved, time: date(2026, 11, 17, $0.0, $0.1)) }
    }

    @Test func blocksStartAtMidnightInFixedSteps() {
        let block = MovementBlock(containing: date(2026, 11, 17, 11, 20), hours: 2, events: [], calendar: calendar)
        #expect(block.start == date(2026, 11, 17, 10))
        #expect(block.end == date(2026, 11, 17, 12))
    }

    @Test func countsOnlyMovementsInsideTheBlock() {
        let events = moves([(9, 59), (10, 0), (10, 30), (11, 59), (12, 0)]) + [LaborEvent(kind: .note, time: date(2026, 11, 17, 10, 5), text: "x")]
        let block = MovementBlock(containing: date(2026, 11, 17, 11), hours: 2, events: events, calendar: calendar)
        #expect(block.count == 3)
        #expect(block.previous(events: events, calendar: calendar).count == 1)
    }

    @Test func lastBlockEndsAtMidnight() {
        let block = MovementBlock(containing: date(2026, 11, 17, 22), hours: 3, events: [], calendar: calendar)
        #expect(block.start == date(2026, 11, 17, 21))
        #expect(block.end == date(2026, 11, 18))
    }

    private func mode(events: [LaborEvent] = [], contractions: [Contraction] = [], weeksAgo due: Int? = nil) -> LaborAnalysis.ButtonMode {
        let now = date(2026, 11, 17, 12)
        var settings = LaborSettings()
        settings.dueDate = due.map { calendar.date(byAdding: .day, value: 280 - $0 * 7, to: now) } ?? nil
        return LaborAnalysis(contractions: contractions, events: events, settings: settings, now: now, calendar: calendar).buttonMode
    }

    @Test func bigButtonCountsMovementsBeforeLabor() {
        #expect(mode(weeksAgo: 34) == .movement)
        #expect(mode() == .movement)
        #expect(mode(weeksAgo: 20) == .contraction)
    }

    @Test func bigButtonTimesContractionsOnceTheyStart() {
        let now = date(2026, 11, 17, 12)
        #expect(mode(contractions: [Contraction(start: now.addingTimeInterval(-300), end: now.addingTimeInterval(-240))], weeksAgo: 38) == .contraction)
        #expect(mode(events: [LaborEvent(kind: .stage, time: now.addingTimeInterval(-60), stage: .early)], weeksAgo: 38) == .contraction)
    }

    @Test func bigButtonCountsFeedsAfterTheBirth() {
        let now = date(2026, 11, 17, 12)
        #expect(mode(events: [LaborEvent(kind: .stage, time: now.addingTimeInterval(-3600), stage: .born)], weeksAgo: 39) == .feeding)
    }
}
