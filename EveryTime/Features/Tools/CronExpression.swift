import Foundation

struct CronExpression: Equatable {
    enum Field: Int, CaseIterable {
        case minute, hour, dayOfMonth, month, dayOfWeek

        var name: String {
            switch self {
            case .minute: "minute"
            case .hour: "hour"
            case .dayOfMonth: "day of month"
            case .month: "month"
            case .dayOfWeek: "day of week"
            }
        }

        var validRange: ClosedRange<Int> {
            switch self {
            case .minute: 0...59
            case .hour: 0...23
            case .dayOfMonth: 1...31
            case .month: 1...12
            case .dayOfWeek: 0...7
            }
        }

        var wildcardRange: ClosedRange<Int> {
            self == .dayOfWeek ? 0...6 : validRange
        }

        fileprivate var names: [String] {
            switch self {
            case .month: ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
            case .dayOfWeek: ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
            default: []
            }
        }

        fileprivate var nameOffset: Int { self == .month ? 1 : 0 }
    }

    struct Part: Equatable {
        let lower: Int
        let upper: Int
        let step: Int
        let isWildcard: Bool

        var values: [Int] { Array(stride(from: lower, through: upper, by: step)) }
        var isSingle: Bool { !isWildcard && lower == upper }
    }

    static let macros = [
        "@yearly": "0 0 1 1 *",
        "@annually": "0 0 1 1 *",
        "@monthly": "0 0 1 * *",
        "@weekly": "0 0 * * 0",
        "@daily": "0 0 * * *",
        "@midnight": "0 0 * * *",
        "@hourly": "0 * * * *",
    ]

    let fields: [[Part]]
    let isDayOfMonthRestricted: Bool
    let isDayOfWeekRestricted: Bool

    init(_ string: String) throws {
        var text = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw CronError.empty }
        if text.hasPrefix("@") {
            guard let expanded = Self.macros[text.lowercased()] else { throw CronError.unknownMacro(text) }
            text = expanded
        }
        let tokens = text.split(whereSeparator: \.isWhitespace)
        guard tokens.count == 5 else { throw CronError.fieldCount(tokens.count) }

        fields = try zip(Field.allCases, tokens).map { field, token in
            try token.split(separator: ",", omittingEmptySubsequences: false).map { try Self.parsePart($0, field: field) }
        }
        isDayOfMonthRestricted = !tokens[Field.dayOfMonth.rawValue].hasPrefix("*")
        isDayOfWeekRestricted = !tokens[Field.dayOfWeek.rawValue].hasPrefix("*")
    }

    func values(_ field: Field) -> Set<Int> {
        let values = Set(fields[field.rawValue].flatMap(\.values))
        return field == .dayOfWeek ? Set(values.map { $0 % 7 }) : values
    }

    func matchesDay(_ date: Date, calendar: Calendar = .current) -> Bool {
        dayMatcher(calendar: calendar)(date)
    }

    private func dayMatcher(calendar: Calendar) -> (Date) -> Bool {
        let months = values(.month), days = values(.dayOfMonth), weekdays = values(.dayOfWeek)
        let either = isDayOfMonthRestricted && isDayOfWeekRestricted
        return { date in
            let c = calendar.dateComponents([.month, .day, .weekday], from: date)
            guard let month = c.month, let day = c.day, let weekday = c.weekday, months.contains(month) else { return false }
            let dayOK = days.contains(day)
            let weekdayOK = weekdays.contains(weekday - 1)
            return either ? dayOK || weekdayOK : dayOK && weekdayOK
        }
    }

    func nextRuns(after start: Date, count: Int = 5, calendar: Calendar = .current) -> [Date] {
        let hours = values(.hour).sorted()
        let minutes = values(.minute).sorted()
        let matches = dayMatcher(calendar: calendar)
        var runs: [Date] = []
        var day = calendar.startOfDay(for: start)
        // Long enough to find several leap-day-only runs.
        for _ in 0..<(366 * 28) {
            if matches(day) {
                var c = calendar.dateComponents([.year, .month, .day], from: day)
                for hour in hours {
                    for minute in minutes {
                        c.hour = hour
                        c.minute = minute
                        guard let run = calendar.date(from: c), run > start,
                              calendar.component(.hour, from: run) == hour,
                              calendar.component(.minute, from: run) == minute
                        else { continue }
                        runs.append(run)
                        if runs.count == count { return runs }
                    }
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return runs
    }

    private static func parsePart(_ token: Substring, field: Field) throws -> Part {
        let pieces = token.split(separator: "/", omittingEmptySubsequences: false)
        guard (1...2).contains(pieces.count) else { throw CronError.invalidValue(String(token), field: field) }

        var step = 1
        if pieces.count == 2 {
            guard let value = Int(pieces[1]), value > 0 else { throw CronError.invalidStep(String(pieces[1]), field: field) }
            step = value
        }

        let base = pieces[0]
        if base == "*" {
            return Part(lower: field.wildcardRange.lowerBound, upper: field.wildcardRange.upperBound, step: step, isWildcard: true)
        }

        let ends = base.split(separator: "-", omittingEmptySubsequences: false)
        guard (1...2).contains(ends.count) else { throw CronError.invalidValue(String(base), field: field) }
        let lower = try parseValue(ends[0], field: field)
        let upper = try ends.count == 2 ? parseValue(ends[1], field: field)
            : pieces.count == 2 ? field.wildcardRange.upperBound : lower
        guard lower <= upper else { throw CronError.reversedRange(String(base), field: field) }
        return Part(lower: lower, upper: upper, step: step, isWildcard: false)
    }

    private static func parseValue(_ token: Substring, field: Field) throws -> Int {
        let value: Int
        if let number = Int(token) {
            value = number
        } else if let index = field.names.firstIndex(of: token.uppercased()) {
            value = index + field.nameOffset
        } else {
            throw CronError.invalidValue(String(token), field: field)
        }
        guard field.validRange.contains(value) else { throw CronError.outOfRange(value, field: field) }
        return value
    }
}

enum CronError: LocalizedError, Equatable {
    case empty
    case unknownMacro(String)
    case fieldCount(Int)
    case invalidValue(String, field: CronExpression.Field)
    case invalidStep(String, field: CronExpression.Field)
    case outOfRange(Int, field: CronExpression.Field)
    case reversedRange(String, field: CronExpression.Field)

    var errorDescription: String? {
        switch self {
        case .empty:
            "Enter a cron expression"
        case .unknownMacro(let macro):
            "Unsupported shortcut \(macro)"
        case .fieldCount(let count):
            "Expected 5 fields, got \(count)"
        case .invalidValue(let token, let field):
            "Invalid \(field.name) \"\(token)\""
        case .invalidStep(let token, let field):
            "Invalid step \"\(token)\" in \(field.name)"
        case .outOfRange(let value, let field):
            "\(field.name.capitalized) \(value) is outside \(field.validRange.lowerBound)–\(field.validRange.upperBound)"
        case .reversedRange(let token, let field):
            "Range \(token) in \(field.name) goes backwards"
        }
    }
}

// MARK: - Summary

extension CronExpression {
    var summary: String {
        let days = dayPhrases
        var phrases = [timePhrase] + days
        if days.isEmpty, specificTimes != nil {
            phrases.append("every day")
        }
        return phrases.joined(separator: ", ")
    }

    private var specificTimes: [String]? {
        guard let minutes = singleValues(.minute), let hours = singleValues(.hour), minutes.count * hours.count <= 4 else { return nil }
        return hours.flatMap { h in minutes.map { Self.formatTime(hour: h, minute: $0) } }
    }

    private func parts(_ field: Field) -> [Part] { fields[field.rawValue] }

    private func isEvery(_ field: Field) -> Bool {
        parts(field).contains { $0.isWildcard && $0.step == 1 }
    }

    private func singleValues(_ field: Field) -> [Int]? {
        let parts = parts(field)
        return parts.allSatisfy(\.isSingle) ? parts.map(\.lower) : nil
    }

    private var timePhrase: String {
        if let times = specificTimes {
            return "At " + ListFormatter.localizedString(byJoining: times)
        }

        var phrases: [String] = []
        let minuteParts = parts(.minute)
        if isEvery(.minute) {
            phrases.append("Every minute")
        } else if minuteParts.count == 1, minuteParts[0].isWildcard {
            phrases.append("Every \(minuteParts[0].step) minutes")
        } else if let minutes = singleValues(.minute), minutes.count == 1 {
            let mark = String(format: ":%02d", minutes[0])
            phrases.append(isEvery(.hour) ? "Every hour at \(mark)" : "At \(mark)")
        } else {
            phrases.append("At minutes " + describe(.minute))
        }

        if !isEvery(.hour) {
            phrases.append(describe(.hour))
        }
        return phrases.joined(separator: ", ")
    }

    private var dayPhrases: [String] {
        var phrases: [String] = []
        let dom = isEvery(.dayOfMonth) ? nil : Self.dayOfMonthPhrase(describe(.dayOfMonth))
        let dow = isEvery(.dayOfWeek) ? nil : describe(.dayOfWeek)
        if let dom, let dow, isDayOfMonthRestricted, isDayOfWeekRestricted {
            phrases.append("\(dom) or \(dow)")
        } else {
            phrases += [dom, dow].compactMap { $0 }
        }
        if !isEvery(.month) {
            let months = describe(.month)
            phrases.append(months.hasPrefix("every") ? months : "in " + months)
        }
        return phrases
    }

    private static func dayOfMonthPhrase(_ description: String) -> String {
        description.hasPrefix("every") ? description : "on day " + description
    }

    private func describe(_ field: Field) -> String {
        parts(field).map { part in
            if part.isWildcard {
                return part.step == 1 ? "every \(Self.unit(field))" : "every \(part.step) \(Self.unit(field))s"
            }
            let range: String
            if part.lower == part.upper {
                range = Self.label(part.lower, field: field)
            } else if field == .hour {
                range = "\(part.lower)–\(part.upper)h"
            } else {
                range = "\(Self.label(part.lower, field: field))–\(Self.label(part.upper, field: field))"
            }
            return part.step == 1 ? range : "\(range) every \(part.step)"
        }
        .joined(separator: ", ")
    }

    private static func unit(_ field: Field) -> String {
        switch field {
        case .dayOfMonth, .dayOfWeek: "day"
        default: field.name
        }
    }

    private static func label(_ value: Int, field: Field) -> String {
        switch field {
        case .hour: "\(value)h"
        case .month: Calendar.current.shortMonthSymbols[value - 1]
        case .dayOfWeek: Calendar.current.shortWeekdaySymbols[value % 7]
        default: "\(value)"
        }
    }

    private static func formatTime(hour: Int, minute: Int) -> String {
        let date = Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 1, hour: hour, minute: minute)) ?? .now
        return date.formatted(.dateTime.hour().minute())
    }
}
