import Foundation
import Testing
@testable import EveryTime

struct FeelingLogTests {
    private let happy = Feeling.builtIn.first { $0.id == "happy" }!
    private let sad = Feeling.builtIn.first { $0.id == "sad" }!
    private let tired = Feeling.builtIn.first { $0.id == "tired" }!

    @Test func staleOpenFeelingClosesAtMaxOpen() {
        let log = FeelingLog(marks: []).starting(happy, at: date(2026, 9, 27, 9))
            .starting(sad, at: date(2026, 9, 28, 10))
        #expect(log.marks[0].end == date(2026, 9, 27, 21))
        #expect(log.marks[1].end == nil)
    }

    @Test func recentOpenFeelingEndsAtTheNewStart() {
        let log = FeelingLog(marks: []).starting(happy, at: date(2026, 9, 28, 9))
            .starting(sad, at: date(2026, 9, 28, 10))
        #expect(log.marks[0].end == date(2026, 9, 28, 10))
    }

    @Test func pastStartEndsAtTheNextOfItsKind() {
        let log = FeelingLog(marks: []).starting(happy, at: date(2026, 9, 28, 10))
            .starting(sad, at: date(2026, 9, 28, 8))
        #expect(log.marks[0].end == nil)
        #expect(log.marks[1].end == date(2026, 9, 28, 10))
        #expect(log.active(at: date(2026, 9, 28, 14)).map(\.feeling) == ["happy"])
    }

    @Test func otherKindsOverlay() {
        let log = FeelingLog(marks: []).starting(happy, at: date(2026, 9, 28, 10))
            .starting(tired, at: date(2026, 9, 28, 8))
        #expect(log.marks.allSatisfy { $0.end == nil })
    }
}
