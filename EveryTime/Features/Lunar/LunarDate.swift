import Foundation

struct LunarDate: Equatable {
    var month: Int
    var day: Int
    var isLeapMonth = false

    private static let digits = ["", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]

    var chineseMonth: String {
        let name = month == 1 ? "正" : month <= 10 ? Self.digits[month] : "十" + Self.digits[month - 10]
        return (isLeapMonth ? "闰" : "") + name + "月"
    }

    var chineseDay: String {
        switch day {
        case 1...10: "初" + Self.digits[day]
        case 20, 30: Self.digits[day / 10] + "十"
        case 11...19: "十" + Self.digits[day % 10]
        case 21...29: "廿" + Self.digits[day % 10]
        default: "\(day)"
        }
    }

    var chinese: String { chineseMonth + chineseDay }
    var numeric: String { "Lunar \(month)/\(day)" }
}

enum LunarRepeat: String, Codable, CaseIterable {
    case never, monthly, yearly

    var title: String {
        switch self {
        case .never: "Never"
        case .monthly: "Every month"
        case .yearly: "Every year"
        }
    }

    var caption: String {
        switch self {
        case .never: "Once"
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        }
    }

    var exportCount: Int {
        switch self {
        case .never: 1
        case .monthly: 24
        case .yearly: 10
        }
    }
}

struct LunarEvent: Identifiable, Codable {
    var id = UUID()
    var name: String
    var month: Int
    var day: Int
    var `repeat`: LunarRepeat = .yearly
    var created = Date.now
    var calendarEventIDs: [String] = []

    var lunar: LunarDate { LunarDate(month: month, day: day) }

    init(name: String, month: Int, day: Int, repeat rule: LunarRepeat = .yearly, created: Date = .now) {
        self.name = name
        self.month = month
        self.day = day
        self.repeat = rule
        self.created = created
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        month = try c.decode(Int.self, forKey: .month)
        day = try c.decode(Int.self, forKey: .day)
        self.repeat = try c.decodeIfPresent(LunarRepeat.self, forKey: .repeat) ?? .yearly
        created = try c.decodeIfPresent(Date.self, forKey: .created) ?? .now
        calendarEventIDs = try c.decodeIfPresent([String].self, forKey: .calendarEventIDs) ?? []
    }
}

enum Lunar {
    static func calendar(timeZone: TimeZone = .current) -> Calendar {
        var cal = Calendar(identifier: .chinese)
        cal.timeZone = timeZone
        return cal
    }

    static func date(of date: Date, calendar cal: Calendar = calendar()) -> LunarDate {
        let c = cal.dateComponents([.month, .day], from: date)
        return LunarDate(month: c.month ?? 1, day: c.day ?? 1, isLeapMonth: c.isLeapMonth ?? false)
    }

    static func stemBranchYear(of date: Date, calendar cal: Calendar = calendar()) -> String {
        let f = DateFormatter()
        f.calendar = cal
        f.timeZone = cal.timeZone
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "U年"
        return f.string(from: date)
    }

    static func nextOccurrence(month: Int, day: Int, from now: Date = .now, calendar cal: Calendar = calendar()) -> Date? {
        occurrences(month: month, day: day, repeat: .yearly, count: 1, from: now, calendar: cal).first
    }

    /// Next `count` Gregorian dates (today or later) for a lunar month/day.
    static func occurrences(month: Int, day: Int, repeat rule: LunarRepeat, count: Int, from now: Date = .now, calendar cal: Calendar = calendar()) -> [Date] {
        let today = cal.startOfDay(for: now)
        let step: Calendar.Component
        var first: Date
        switch rule {
        case .monthly:
            guard let start = cal.dateInterval(of: .month, for: today)?.start else { return [] }
            first = start
            step = .month
        case .yearly, .never:
            var c = cal.dateComponents([.era, .year], from: today)
            c.month = month
            c.day = 1
            c.isLeapMonth = false
            guard let start = cal.date(from: c) else { return [] }
            first = start
            step = .year
        }
        let limit = rule == .never ? 1 : count
        var dates: [Date] = []
        for _ in 0..<(limit + 2) where dates.count < limit {
            if let date = clamped(day: day, monthStart: first, calendar: cal), date >= today { dates.append(date) }
            guard let next = cal.date(byAdding: step, value: 1, to: first) else { break }
            first = next
        }
        return dates
    }

    /// Dates to export: yearly next 10, monthly next 24, once for `.never` (anchored at creation).
    static func occurrences(of event: LunarEvent, count: Int? = nil, from now: Date = .now, calendar cal: Calendar = calendar()) -> [Date] {
        let from = event.repeat == .never ? event.created : now
        return occurrences(month: event.month, day: event.day, repeat: event.repeat,
                           count: count ?? event.repeat.exportCount, from: from, calendar: cal)
    }

    static func daysUntil(_ date: Date, from now: Date = .now, calendar cal: Calendar = calendar()) -> Int {
        cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: date)).day ?? 0
    }

    private static func clamped(day: Int, monthStart: Date, calendar cal: Calendar) -> Date? {
        guard let length = cal.range(of: .day, in: .month, for: monthStart)?.count else { return nil }
        return cal.date(byAdding: .day, value: min(max(day, 1), length) - 1, to: monthStart)
    }
}
