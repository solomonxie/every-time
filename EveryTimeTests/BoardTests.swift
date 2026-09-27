import Foundation
import Testing
@testable import EveryTime

struct CardTrailerTests {
    @Test func writesOneLineAfterTheNotes() {
        #expect(CardTrailer.write(body: "Bosch 6 mm", column: "In progress", points: 3) == "Bosch 6 mm\n\n— Board: In progress · 3 pts")
        #expect(CardTrailer.write(body: "", column: "Backlog", points: 1) == "— Board: Backlog · 1 pt")
        #expect(CardTrailer.write(body: "  just notes \n", column: nil, points: 0) == "just notes")
        #expect(CardTrailer.write(body: "", column: nil, points: nil) == nil)
    }

    @Test func roundTrips() {
        let notes = CardTrailer.write(body: "line one\nline two", column: "Review", points: 5)
        let parsed = CardTrailer.parse(notes)
        #expect(parsed.body == "line one\nline two")
        #expect(parsed.column == "Review")
        #expect(parsed.points == 5)
    }

    @Test func readsHandEditedTrailers() {
        #expect(CardTrailer.parse("- board: doing").column == "doing")
        #expect(CardTrailer.parse("x\n—Board:Review·2pt\n\n").column == "Review")
        #expect(CardTrailer.parse("x\n—Board:Review·2pt").points == 2)
        #expect(CardTrailer.parse("— Board: · 3 pts").column == nil)
        #expect(CardTrailer.parse("— Board: · 3 pts").points == 3)
    }

    @Test func leavesOrdinaryNotesAlone() {
        let notes = "Board meeting at 3\nbring slides"
        let parsed = CardTrailer.parse(notes)
        #expect(parsed.body == notes)
        #expect(parsed.column == nil)
        #expect(CardTrailer.parse(nil).body == "")
    }
}

struct BoardConfigTests {
    private func card(column: String?, done: Bool = false) -> BoardCard {
        BoardCard(id: "1", title: "t", notes: "", column: column, priority: 0, isCompleted: done)
    }

    @Test func placesCardsByTrailerElseFirstColumn() {
        let config = BoardConfig(listID: "L")
        #expect(config.column(of: card(column: "in PROGRESS"))?.name == "In progress")
        #expect(config.column(of: card(column: "Nowhere"))?.name == "Backlog")
        #expect(config.column(of: card(column: nil))?.name == "Backlog")
        #expect(config.column(of: card(column: "Review", done: true)) == nil)
    }
}
