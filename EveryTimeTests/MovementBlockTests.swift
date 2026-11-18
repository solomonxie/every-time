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
}
