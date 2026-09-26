import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// A stretch of work or break; `end == nil` while it's running.
struct WorkSpan: Identifiable, Codable, Hashable {
    enum Kind: String, Codable { case work, rest }

    var id = UUID()
    var kind: Kind
    var start: Date
    var end: Date?
}

/// One calendar day of the log; spans crossing midnight are split between days.
struct WorkDay: Identifiable, Hashable {
    let date: Date
    var firstIn: Date
    var lastOut: Date
    var worked: TimeInterval = 0
    var rested: TimeInterval = 0
    var isOpen = false

    var id: Date { date }
}

/// Clock in/out and breaks as consecutive spans, oldest first.
struct WorkLog {
    static let key = "timers.workLog"

    enum State { case off, working, onBreak }

    var spans: [WorkSpan]

    var state: State {
        guard let last = spans.last, last.end == nil else { return .off }
        return last.kind == .work ? .working : .onBreak
    }

    var openSince: Date? { spans.last.flatMap { $0.end == nil ? $0.start : nil } }

    mutating func clockIn(at now: Date = .now) { begin(.work, at: now) }
    mutating func startBreak(at now: Date = .now) { begin(.rest, at: now) }
    mutating func clockOut(at now: Date = .now) { close(at: now) }

    mutating func deleteDay(_ date: Date, calendar: Calendar = .current) {
        spans.removeAll { calendar.isDate($0.start, inSameDayAs: date) }
    }

    private mutating func begin(_ kind: WorkSpan.Kind, at now: Date) {
        close(at: now)
        spans.append(WorkSpan(kind: kind, start: now))
    }

    private mutating func close(at now: Date) {
        guard let i = spans.indices.last, spans[i].end == nil else { return }
        spans[i].end = now
    }

    func today(at now: Date = .now, calendar: Calendar = .current) -> WorkDay? {
        let start = calendar.startOfDay(for: now)
        return WorkLog(spans: spans.filter { ($0.end ?? now) > start })
            .days(at: now, calendar: calendar)
            .first { $0.date == start }
    }

    /// Days with any work, newest first.
    func days(at now: Date = .now, calendar: Calendar = .current) -> [WorkDay] {
        var byDay: [Date: WorkDay] = [:]
        for span in spans {
            let end = span.end ?? now
            var from = span.start
            while from < end {
                let day = calendar.startOfDay(for: from)
                let to = min(end, calendar.date(byAdding: .day, value: 1, to: day) ?? end)
                var entry = byDay[day] ?? WorkDay(date: day, firstIn: .distantFuture, lastOut: .distantPast)
                switch span.kind {
                case .work:
                    entry.worked += to.timeIntervalSince(from)
                    entry.firstIn = min(entry.firstIn, from)
                    entry.lastOut = max(entry.lastOut, to)
                case .rest:
                    entry.rested += to.timeIntervalSince(from)
                }
                if span.end == nil && to == end { entry.isOpen = true }
                byDay[day] = entry
                from = to
            }
        }
        return byDay.values.filter { $0.worked > 0 }.sorted { $0.date > $1.date }
    }

    func csv(at now: Date = .now) -> String {
        let date = Self.formatter("yyyy-MM-dd")
        let time = Self.formatter("HH:mm")
        let rows = days(at: now).reversed().map { day in
            [
                date.string(from: day.date),
                time.string(from: day.firstIn),
                day.isOpen ? "" : time.string(from: day.lastOut),
                Self.hoursMinutes(day.worked),
                String(format: "%.2f", day.worked / 3600),
                Self.hoursMinutes(day.rested),
            ].joined(separator: ",")
        }
        return (["Date,Clock in,Clock out,Worked,Worked hours,Break"] + rows).joined(separator: "\n") + "\n"
    }

    /// `h:mm`
    static func hoursMinutes(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        return String(format: "%d:%02d", minutes / 60, minutes % 60)
    }

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter
    }
}

struct CSVFile: Transferable {
    let text: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { Data($0.text.utf8) }
            .suggestedFileName("Work hours.csv")
    }
}
