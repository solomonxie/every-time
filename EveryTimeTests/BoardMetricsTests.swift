import Foundation
import Testing
@testable import EveryTime

/// Now is Saturday 2026-09-26 noon; weeks start Sunday, so this week is Sep 20–27.
struct BoardMetricsTests {
    private let now = date(2026, 9, 26, 12)

    private func card(_ id: String, column: String? = nil, points: Int? = nil,
                      due: (Int, Int, Int)? = nil, dueHour: Int? = nil,
                      created: Date? = nil, completed: Date? = nil) -> BoardCard {
        BoardCard(id: id, title: id, notes: "", column: column, points: points,
                  due: due.map { DateComponents(year: $0.0, month: $0.1, day: $0.2, hour: dueHour) },
                  priority: 0, isCompleted: completed != nil, completedAt: completed, createdAt: created)
    }

    private func metrics(_ cards: [BoardCard]) -> BoardMetrics {
        BoardMetrics(cards: cards, now: now, calendar: gregorian())
    }

    @Test func progressCountsOverdueAndDueThisWeek() {
        let p = metrics([
            card("late", due: (2026, 9, 24)),
            card("today", due: (2026, 9, 26)),
            card("earlier today", due: (2026, 9, 26), dueHour: 10),
            card("next week", due: (2026, 10, 5)),
            card("done1", due: (2026, 9, 1), completed: date(2026, 9, 2)),
            card("done2", completed: date(2026, 9, 3)),
        ]).progress
        #expect(p == .init(done: 2, open: 4, overdue: 2, dueThisWeek: 1))
        #expect(p.fraction == 2.0 / 6)
        #expect(BoardMetrics.Progress().fraction == 0)
    }

    @Test func eightWeeksEndingThisWeek() {
        let weeks = metrics([]).weeks
        #expect(weeks.count == 8)
        #expect(weeks.first?.start == date(2026, 8, 2))
        #expect(weeks.last?.start == date(2026, 9, 20))
        #expect(weeks.last?.contains(now) == true)
    }

    @Test func burnUpIsCumulativeCreatedVersusCompleted() {
        let points = metrics([
            card("old", created: date(2026, 7, 1), completed: date(2026, 8, 5)),
            card("mid", created: date(2026, 8, 10), completed: date(2026, 9, 22)),
            card("new", created: date(2026, 9, 25)),
            card("unknown"),
        ]).burnUp
        #expect(points.count == 9)
        #expect(points[0] == .init(date: date(2026, 8, 2), created: 2, completed: 0))
        #expect(points[1] == .init(date: date(2026, 8, 9), created: 2, completed: 1))
        #expect(points[2].created == 3)
        #expect(points.last == .init(date: now, created: 4, completed: 2))
    }

    @Test func velocityCountsCardsWithoutPoints() {
        let m = metrics([
            card("a", completed: date(2026, 8, 3)),
            card("b", completed: date(2026, 9, 21)),
            card("c", completed: date(2026, 9, 26, 9)),
            card("too old", completed: date(2026, 7, 1)),
            card("open"),
        ])
        #expect(!m.usesPoints)
        #expect(m.velocity.map(\.value) == [1, 0, 0, 0, 0, 0, 0, 2])
        #expect(m.velocityAverage == 3.0 / 8)
    }

    @Test func velocitySumsPointsWhenAnyCardHasThem() {
        let m = metrics([
            card("a", points: 3, completed: date(2026, 9, 21)),
            card("b", completed: date(2026, 9, 22)),
            card("open", points: 5),
        ])
        #expect(m.usesPoints)
        #expect(m.velocity.last?.value == 3)
        #expect(m.velocityAverage == 3.0 / 8)
    }

    @Test func byColumnInBoardOrderDoneLast() {
        let config = BoardConfig(listID: "L")
        let counts = metrics([
            card("r", column: "review"), card("x", column: nil), card("y", column: "Gone"),
            card("d", column: "Review", completed: now),
        ]).byColumn(config)
        #expect(counts.map(\.name) == ["Backlog", "In progress", "Review", "Done"])
        #expect(counts.map(\.count) == [2, 0, 1, 1])
    }

    @Test func flowUsesCurrentColumnsAndZeroFills() {
        let history: [(date: Date, counts: BoardFlow.Day)] = [
            (date(2026, 9, 1), ["Backlog": 4, "Old name": 2]),
            (date(2026, 9, 2), ["Backlog": 3, "Done": 1]),
        ]
        let points = BoardMetrics.flow(history, columns: ["Backlog", "Done"])
        #expect(points == [
            .init(date: date(2026, 9, 1), column: "Backlog", count: 4),
            .init(date: date(2026, 9, 1), column: "Done", count: 0),
            .init(date: date(2026, 9, 2), column: "Backlog", count: 3),
            .init(date: date(2026, 9, 2), column: "Done", count: 1),
        ])
    }

    @Test func roadmapSortsByDueAndSpansAtLeastFourWeeks() {
        let map = metrics([
            card("later", due: (2026, 10, 1)),
            card("sooner", due: (2026, 9, 25)),
            card("undated"),
            card("done", due: (2026, 9, 24), completed: now),
        ]).roadmap(milestones: [])
        #expect(map.rows.map(\.id) == ["sooner", "later"])
        #expect(map.undated.map(\.id) == ["undated"])
        #expect(map.window == DateInterval(start: date(2026, 9, 20), end: date(2026, 10, 18)))
        #expect(map.weekStarts == [date(2026, 9, 20), date(2026, 9, 27), date(2026, 10, 4), date(2026, 10, 11)])
        #expect(map.position(of: date(2026, 10, 4)) == 0.5)
    }

    @Test func roadmapClampsOverdueAndFarMilestones() {
        let milestones = [
            BoardStore.Milestone(id: "past", title: "Past", date: date(2026, 1, 1)),
            BoardStore.Milestone(id: "v1", title: "v1", date: date(2026, 11, 4)),
            BoardStore.Milestone(id: "far", title: "Far", date: date(2027, 9, 1)),
        ]
        let map = metrics([card("ancient", due: (2026, 6, 1))]).roadmap(milestones: milestones)
        #expect(map.window.start == date(2026, 8, 23))
        #expect(map.window.end == date(2027, 3, 21))
        #expect(map.milestones.map(\.id) == ["v1"])
        #expect(map.position(of: date(2026, 6, 1)) == 0)
        #expect(map.position(of: date(2028, 1, 1)) == 1)
    }

    @Test func roadmapExtendsToTheLastMilestoneWeek() {
        let map = metrics([]).roadmap(milestones: [.init(id: "v1", title: "v1", date: date(2026, 11, 4))])
        #expect(map.window == DateInterval(start: date(2026, 9, 20), end: date(2026, 11, 8)))
        #expect(map.weekStarts.count == 7)
    }
}
