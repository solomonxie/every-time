import Foundation

enum EventType: String, Codable, CaseIterable, Identifiable {
    case birthday, anniversary, wedding, relationship, memorial, milestone, other

    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .birthday: "birthday.cake"
        case .anniversary: "heart"
        case .wedding: "figure.2.and.child.holdinghands"
        case .relationship: "heart.circle"
        case .memorial: "leaf"
        case .milestone: "flag"
        case .other: "star"
        }
    }

    /// Guess from a calendar event's title and calendar.
    static func guess(title: String, isBirthdayCalendar: Bool) -> EventType {
        let t = title.lowercased()
        if isBirthdayCalendar || t.contains("birthday") || t.contains("生日") { return .birthday }
        if t.contains("anniversary") || t.contains("纪念") { return .anniversary }
        return .other
    }
}

enum EventSource: Codable, Hashable {
    case manual
    /// EKEvent calendarItemIdentifier + title at the time it was picked.
    case calendar(id: String, title: String)
}

/// Stored under "calendar.since"; decodes the older name/date-only items.
struct ImportantEvent: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var date: Date
    var type: EventType = .other
    var source: EventSource = .manual
    var notify = true
    /// Countdowns to timed events tick down to hours/minutes; all-day ones count days.
    var hasTime = false

    init(id: UUID = UUID(), name: String, date: Date, type: EventType = .other, source: EventSource = .manual,
         notify: Bool = true, hasTime: Bool = false) {
        (self.id, self.name, self.date, self.type, self.source, self.notify, self.hasTime) = (id, name, date, type, source, notify, hasTime)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        date = try c.decode(Date.self, forKey: .date)
        type = (try? c.decodeIfPresent(EventType.self, forKey: .type)) ?? .other
        source = (try? c.decodeIfPresent(EventSource.self, forKey: .source)) ?? .manual
        notify = try c.decodeIfPresent(Bool.self, forKey: .notify) ?? true
        hasTime = try c.decodeIfPresent(Bool.self, forKey: .hasTime) ?? false
    }

    func isFuture(at now: Date, calendar: Calendar = .current) -> Bool {
        hasTime ? date > now : calendar.startOfDay(for: date) > calendar.startOfDay(for: now)
    }
}

extension ImportantEvent {
    static let storageKey = "calendar.since"
}
