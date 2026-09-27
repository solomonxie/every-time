import Foundation

/// A board column; Done is implicit and always last (it completes the reminder).
struct BoardColumn: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var wipLimit: Int?

    init(_ name: String, wipLimit: Int? = nil) {
        self.name = name
        self.wipLimit = wipLimit
    }
}

/// Per-board settings kept in the app (`boards.config`); the cards themselves live in Reminders.
struct BoardConfig: Codable, Hashable, Identifiable {
    var listID: String
    var columns: [BoardColumn]
    var milestoneCalendarID: String?

    var id: String { listID }

    static let storageKey = "boards.config"
    static let flowKey = "boards.flow"
    static let doneName = "Done"

    enum Template: String, CaseIterable, Identifiable {
        case standard, simple, zenhub
        var id: String { rawValue }

        var columns: [String] {
            switch self {
            case .standard: ["Backlog", "In progress", "Review"]
            case .simple: ["To do", "Doing"]
            case .zenhub: ["New", "Icebox", "Backlog", "In progress", "Review"]
            }
        }

        var title: String { (columns + [BoardConfig.doneName]).joined(separator: " · ") }
    }

    init(listID: String, template: Template = .standard) {
        self.listID = listID
        columns = template.columns.map { BoardColumn($0) }
    }

    /// The column a card shows in: Done when completed, else its trailer's column if known, else the first.
    func column(of card: BoardCard) -> BoardColumn? {
        if card.isCompleted { return nil }
        return columns.first { $0.name.caseInsensitiveCompare(card.column ?? "") == .orderedSame } ?? columns.first
    }
}

/// A reminder as the board sees it. `notes` excludes the trailer line.
struct BoardCard: Identifiable, Hashable {
    let id: String
    var externalID: String?
    var title: String
    var notes: String
    var column: String?
    var points: Int?
    var due: DateComponents?
    var priority: Int
    var isCompleted: Bool
    var completedAt: Date?
    var createdAt: Date?

    var dueDate: Date? { due.flatMap { Calendar.current.date(from: $0) } }
    var dueHasTime: Bool { due?.hour != nil }

    func isOverdue(now: Date = .now) -> Bool {
        guard !isCompleted, let dueDate else { return false }
        return dueHasTime ? dueDate < now : Calendar.current.startOfDay(for: now) > dueDate
    }

    /// Opens this reminder in the Reminders app.
    var remindersURL: URL? {
        externalID.flatMap { URL(string: "x-apple-reminderkit://REMCDReminder/\($0)") }
    }
}

/// Column and estimate as one line at the end of a reminder's notes: `— Board: In progress · 3 pts`.
/// Lenient on read (case, dash style, spacing); only this line is ever rewritten.
enum CardTrailer {
    static func parse(_ notes: String?) -> (body: String, column: String?, points: Int?) {
        let notes = notes ?? ""
        var lines = notes.components(separatedBy: .newlines)
        while let last = lines.last, last.trimmingCharacters(in: .whitespaces).isEmpty { lines.removeLast() }
        guard let last = lines.last, let match = last.wholeMatch(of: pattern) else { return (notes, nil, nil) }
        lines.removeLast()
        let column = String(match.1).trimmingCharacters(in: .whitespaces)
        let points = match.2.flatMap { Int($0) }
        return (lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines),
                column.isEmpty ? nil : column, points)
    }

    static func write(body: String, column: String?, points: Int?) -> String? {
        let body = body.trimmingCharacters(in: .whitespacesAndNewlines)
        var parts: [String] = []
        if let column { parts.append(column) }
        if let points, points > 0 { parts.append("\(points) \(points == 1 ? "pt" : "pts")") }
        guard !parts.isEmpty else { return body.isEmpty ? nil : body }
        let trailer = "— Board: " + parts.joined(separator: " · ")
        return body.isEmpty ? trailer : body + "\n\n" + trailer
    }

    // "— Board: In progress · 3 pts", "- board: Review", "—Board: · 2 pt"
    private static var pattern: Regex<(Substring, Substring, Substring?)> {
        #/\s*[—–-]+\s*[Bb][Oo][Aa][Rr][Dd]\s*:\s*([^·]*?)\s*(?:·\s*(\d+)\s*[Pp][Tt][Ss]?)?\s*/#
    }
}
