import Foundation

/// The numbers behind Roadmap and Insights. Pure; `now` and `calendar` are injectable for tests.
struct BoardMetrics {
    let cards: [BoardCard]
    var now: Date = .now
    var calendar: Calendar = .current

    static let weekCount = 8

    // MARK: Progress

    struct Progress: Equatable {
        var done = 0
        var open = 0
        var overdue = 0
        var dueThisWeek = 0

        var fraction: Double { done + open == 0 ? 0 : Double(done) / Double(done + open) }
    }

    var progress: Progress {
        let open = cards.filter { !$0.isCompleted }
        let week = calendar.dateInterval(of: .weekOfYear, for: now)
        return Progress(done: cards.count - open.count, open: open.count,
                        overdue: open.filter(isOverdue).count,
                        dueThisWeek: open.filter { card in
                            guard !isOverdue(card), let due = dueDate(card), let week else { return false }
                            return week.contains(due) && due < week.end
                        }.count)
    }

    func dueDate(_ card: BoardCard) -> Date? { card.due.flatMap { calendar.date(from: $0) } }

    func isOverdue(_ card: BoardCard) -> Bool {
        guard !card.isCompleted, let due = dueDate(card) else { return false }
        return card.dueHasTime ? due < now : calendar.startOfDay(for: now) > due
    }

    // MARK: Weeks

    /// The last `weekCount` calendar weeks, oldest first, ending with the one containing `now`.
    var weeks: [DateInterval] {
        guard let current = calendar.dateInterval(of: .weekOfYear, for: now) else { return [] }
        return (0..<Self.weekCount).reversed().compactMap { back in
            calendar.date(byAdding: .weekOfYear, value: -back, to: current.start)
                .flatMap { calendar.dateInterval(of: .weekOfYear, for: $0) }
        }
    }

    // MARK: Burn-up

    struct BurnPoint: Equatable {
        var date: Date
        var created: Int
        var completed: Int
    }

    /// Cumulative created vs completed at the start of the window and at the end of each week (capped at now).
    var burnUp: [BurnPoint] {
        guard let first = weeks.first else { return [] }
        let stops = [first.start] + weeks.map { min($0.end, now) }
        return stops.map { stop in
            BurnPoint(date: stop,
                      created: cards.filter { ($0.createdAt ?? .distantPast) <= stop }.count,
                      completed: cards.filter { $0.isCompleted && ($0.completedAt ?? .distantFuture) <= stop }.count)
        }
    }

    // MARK: Velocity

    var usesPoints: Bool { cards.contains { ($0.points ?? 0) > 0 } }

    struct WeekValue: Equatable {
        var start: Date
        var value: Int
    }

    /// Completed per week — points when any card has points, else cards.
    var velocity: [WeekValue] {
        let points = usesPoints
        return weeks.map { week in
            let done = cards.filter { card in
                guard card.isCompleted, let at = card.completedAt else { return false }
                return at >= week.start && at < week.end
            }
            return WeekValue(start: week.start, value: done.reduce(0) { $0 + (points ? $1.points ?? 0 : 1) })
        }
    }

    var velocityAverage: Double {
        let weeks = velocity
        return weeks.isEmpty ? 0 : Double(weeks.reduce(0) { $0 + $1.value }) / Double(weeks.count)
    }

    // MARK: Columns

    struct ColumnCount: Equatable {
        var name: String
        var count: Int
    }

    /// Columns in board order, Done last.
    func byColumn(_ config: BoardConfig) -> [ColumnCount] {
        config.columns.map { column in
            ColumnCount(name: column.name, count: cards.filter { config.column(of: $0)?.id == column.id }.count)
        } + [ColumnCount(name: BoardConfig.doneName, count: cards.filter(\.isCompleted).count)]
    }

    static func columnNames(_ config: BoardConfig) -> [String] { config.columns.map(\.name) + [BoardConfig.doneName] }

    // MARK: Flow

    struct FlowPoint: Hashable {
        var date: Date
        var column: String
        var count: Int
    }

    /// Snapshots as stackable points in the board's current column order; retired column names are dropped.
    static func flow(_ history: [(date: Date, counts: BoardFlow.Day)], columns: [String]) -> [FlowPoint] {
        history.flatMap { day in
            columns.map { FlowPoint(date: day.date, column: $0, count: day.counts[$0] ?? 0) }
        }
    }

    // MARK: Roadmap

    struct Roadmap {
        var rows: [BoardCard]
        var undated: [BoardCard]
        var window: DateInterval
        var weekStarts: [Date]
        var milestones: [BoardStore.Milestone]

        /// 0…1 across the window, clamped so off-window dates sit at an edge.
        func position(of date: Date) -> Double {
            guard window.duration > 0 else { return 0 }
            return min(max(date.timeIntervalSince(window.start) / window.duration, 0), 1)
        }
    }

    /// Open cards by due date across weeks: from this week (or up to 4 weeks back for overdue cards)
    /// to the latest due date or milestone, at least 4 and at most 26 weeks ahead.
    func roadmap(milestones: [BoardStore.Milestone]) -> Roadmap {
        let open = cards.filter { !$0.isCompleted }
        let dated: [(card: BoardCard, due: Date)] = open.compactMap { card in dueDate(card).map { (card, $0) } }
            .sorted { a, b in
                a.due != b.due ? a.due < b.due : a.card.title.localizedCaseInsensitiveCompare(b.card.title) == .orderedAscending
            }
        let thisWeek = weekInterval(now).start
        let week = { (n: Int) -> Date in calendar.date(byAdding: .weekOfYear, value: n, to: thisWeek)! }

        let earliest = dated.first.map { weekInterval($0.due).start } ?? thisWeek
        let start = max(min(earliest, thisWeek), week(-4))
        let upcoming: [Date] = milestones.map(\.date).filter { $0 >= start }
        let latest = (dated.map(\.due) + upcoming).max().map { weekInterval($0).end } ?? thisWeek
        let end = min(max(latest, week(4)), week(26))

        var starts: [Date] = []
        var cursor = start
        while cursor < end {
            starts.append(cursor)
            cursor = calendar.date(byAdding: .weekOfYear, value: 1, to: cursor)!
        }
        let window = DateInterval(start: start, end: end)
        return Roadmap(rows: dated.map(\.card), undated: open.filter { dueDate($0) == nil }, window: window,
                       weekStarts: starts, milestones: milestones.filter { window.contains($0.date) })
    }

    private func weekInterval(_ date: Date) -> DateInterval {
        calendar.dateInterval(of: .weekOfYear, for: date) ?? DateInterval(start: calendar.startOfDay(for: date), duration: 7 * 86_400)
    }
}
