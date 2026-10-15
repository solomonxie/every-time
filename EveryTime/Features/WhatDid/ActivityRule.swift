import Foundation

/// A daily pin: the same tag at the same clock time every day. Days up to now are written out once as plain pins.
struct ActivityRule: Identifiable, Codable, Hashable {
    var id = UUID()
    var hour: Int
    var minute: Int
    var tag: String?
    var alarm: Bool?
    /// The first day not written out yet, as yyyymmdd.
    var from: Int
    /// Days (yyyymmdd) whose pin was removed or moved.
    var skipped: [Int] = []

    func time(on day: Int, calendar: Calendar) -> Date? {
        Self.start(of: day, calendar: calendar).flatMap { calendar.date(bySettingHour: hour, minute: minute, second: 0, of: $0) }
    }

    /// Moves `from` past the days whose time has come.
    func starting(after now: Date, calendar: Calendar) -> ActivityRule {
        var rule = self
        while let time = rule.time(on: rule.from, calendar: calendar), time <= now,
              let next = Self.day(after: rule.from, calendar: calendar), next > rule.from {
            rule.from = next
        }
        rule.skipped.removeAll { $0 < rule.from }
        return rule
    }

    static func day(of date: Date, calendar: Calendar) -> Int {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return (parts.year ?? 0) * 10_000 + (parts.month ?? 0) * 100 + (parts.day ?? 0)
    }

    static func start(of day: Int, calendar: Calendar) -> Date? {
        guard isDay(day) else { return nil }
        return calendar.date(from: DateComponents(year: day / 10_000, month: day / 100 % 100, day: day % 100))
    }

    static func day(after day: Int, calendar: Calendar) -> Int? {
        start(of: day, calendar: calendar)
            .flatMap { calendar.date(byAdding: .day, value: 1, to: $0) }
            .map { Self.day(of: $0, calendar: calendar) }
    }

    static func isDay(_ day: Int) -> Bool {
        day > 10_000 && (1...12).contains(day / 100 % 100) && (1...31).contains(day % 100)
    }
}

extension ActivityRule {
    /// Repeats `mark` at its clock time from the day after it, leaving out days already past.
    init(repeating mark: ActivityMark, id: UUID = UUID(), after now: Date, calendar: Calendar) {
        let parts = calendar.dateComponents([.hour, .minute], from: mark.time)
        let day = Self.day(of: mark.time, calendar: calendar)
        self.init(id: id, hour: parts.hour ?? 0, minute: parts.minute ?? 0, tag: mark.tag, alarm: mark.alarm,
                  from: Self.day(after: day, calendar: calendar) ?? day)
        self = starting(after: now, calendar: calendar)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        hour = try c.decode(Int.self, forKey: .hour)
        minute = try c.decode(Int.self, forKey: .minute)
        tag = try c.decodeIfPresent(String.self, forKey: .tag)
        alarm = try c.decodeIfPresent(Bool.self, forKey: .alarm)
        from = try c.decode(Int.self, forKey: .from)
        skipped = try c.decodeIfPresent([Int].self, forKey: .skipped) ?? []
    }
}

/// One day of a rule, not stored until its time comes.
struct ActivityOccurrence {
    let rule: UUID
    let day: Int
    let mark: ActivityMark
}

/// Daily pins: expanded from their rules on read; edits to one day skip it in the rule.
extension ActivityLog {
    static let rulesKey = "timers.activityRules"

    static func stored(in defaults: UserDefaults = AppData.defaults) -> ActivityLog {
        ActivityLog(marks: defaults.decoded(key) ?? [], rules: defaults.decoded(rulesKey) ?? [])
    }

    /// Stored pins plus each rule's days through `end`.
    func pins(through end: Date) -> [ActivityMark] {
        marks + occurrences(through: end).map(\.mark)
    }

    /// Each rule's days from its first unwritten one through `end`, skipped days left out.
    func occurrences(through end: Date) -> [ActivityOccurrence] {
        rules.flatMap { rule in
            var out: [ActivityOccurrence] = []
            var day = rule.from
            while let time = rule.time(on: day, calendar: calendar), time <= end {
                if !rule.skipped.contains(day) {
                    out.append(ActivityOccurrence(rule: rule.id, day: day,
                                                  mark: ActivityMark(id: Self.occurrenceID(rule.id, day: day), time: time, tag: rule.tag)))
                }
                guard let next = ActivityRule.day(after: day, calendar: calendar), next > day else { break }
                day = next
            }
            return out
        }
    }

    /// Some rule has a day whose time has come but isn't written out.
    func isBehind(at now: Date) -> Bool {
        rules.contains { rule in rule.time(on: rule.from, calendar: calendar).map { $0 <= now } ?? false }
    }

    /// Writes out each rule's days up to now as plain pins, so later edits to them stick.
    func caughtUp(at now: Date) -> ActivityLog {
        var log = self
        let ids = Set(marks.map(\.id))
        log.marks += occurrences(through: now).map(\.mark).filter { !ids.contains($0.id) }
        log.rules = rules.map { $0.starting(after: now, calendar: calendar) }
        return log
    }

    /// A stored pin, or a daily pin (by its rule or one of its days) as one pin at its next time.
    func pin(_ id: UUID, at now: Date) -> ActivityMark? {
        if let mark = marks.first(where: { $0.id == id }) { return mark }
        guard let rule = rules.first(where: { $0.id == id }) ?? occurrence(id).map({ rules[$0.index] }) else { return nil }
        let next = rule.starting(after: now, calendar: calendar)
        return ActivityMark(id: rule.id, time: next.time(on: next.from, calendar: calendar) ?? now,
                            tag: rule.tag, alarm: rule.alarm, repeats: "daily")
    }

    /// One day of a daily pin becomes a plain pin with the same id; the rule skips that day.
    func detaching(_ id: UUID) -> ActivityLog {
        guard let (index, day) = occurrence(id), let time = rules[index].time(on: day, calendar: calendar) else { return self }
        var log = self
        log.rules[index].skipped.append(day)
        log.marks.append(ActivityMark(id: id, time: time, tag: rules[index].tag, alarm: rules[index].alarm))
        return log
    }

    /// A pin goes; one day of a daily pin is skipped; a rule's own id stops it (days already written stay).
    func removing(_ id: UUID) -> ActivityLog {
        var log = self
        if marks.contains(where: { $0.id == id }) {
            log.marks.removeAll { $0.id == id }
        } else if rules.contains(where: { $0.id == id }) {
            log.rules.removeAll { $0.id == id }
        } else if let (index, day) = occurrence(id) {
            log.rules[index].skipped.append(day)
        }
        return log
    }

    /// A pin's alarm, or a daily pin's for every day.
    func togglingAlarm(_ id: UUID) -> ActivityLog {
        var log = self
        if let i = marks.firstIndex(where: { $0.id == id }) {
            log.marks[i].alarm = marks[i].alarm != true
        } else if let i = rules.firstIndex(where: { $0.id == id }) ?? occurrence(id)?.index {
            log.rules[i].alarm = rules[i].alarm != true
        }
        return log
    }

    /// The editor's result: a pin, or a rule (repeat on keeps it, off leaves one plain pin at the edited time).
    func saving(_ edited: ActivityMark, at now: Date) -> ActivityLog {
        var log = self
        let time = Self.rounded(edited.time)
        if let i = rules.firstIndex(where: { $0.id == edited.id }) {
            guard edited.isDaily else {
                log.rules.remove(at: i)
                log.marks.append(ActivityMark(time: time, tag: edited.tag, alarm: edited.alarm))
                return log
            }
            let parts = calendar.dateComponents([.hour, .minute], from: time)
            var rule = rules[i]
            (rule.hour, rule.minute, rule.tag, rule.alarm) = (parts.hour ?? 0, parts.minute ?? 0, edited.tag, edited.alarm)
            rule.from = max(rule.from, ActivityRule.day(of: time, calendar: calendar))
            log.rules[i] = rule.starting(after: now, calendar: calendar)
            return log
        }
        guard let i = marks.firstIndex(where: { $0.id == edited.id }) else { return log }
        log.marks[i] = ActivityMark(id: edited.id, time: time, tag: edited.tag, alarm: edited.alarm)
        if edited.isDaily { log.rules.append(ActivityRule(repeating: log.marks[i], after: now, calendar: calendar)) }
        return log
    }

    /// The same id every time for a rule's day.
    static func occurrenceID(_ rule: UUID, day: Int) -> UUID {
        var bytes = rule.uuid
        withUnsafeMutableBytes(of: &bytes) { raw in
            for i in 0..<4 { raw[i] ^= UInt8(truncatingIfNeeded: day >> (8 * (3 - i))) }
        }
        return UUID(uuid: bytes)
    }

    /// The rule and day an id stands for, unless a stored pin has it.
    private func occurrence(_ id: UUID) -> (index: Int, day: Int)? {
        guard !marks.contains(where: { $0.id == id }) else { return nil }
        let a = withUnsafeBytes(of: id.uuid, Array.init)
        for (index, rule) in rules.enumerated() {
            let b = withUnsafeBytes(of: rule.id.uuid, Array.init)
            guard a[4...] == b[4...] else { continue }
            let day = (0..<4).reduce(0) { $0 << 8 | Int(a[$1] ^ b[$1]) }
            if ActivityRule.isDay(day) { return (index, day) }
        }
        return nil
    }
}

/// Before rules, a daily pin was a pin marked "daily" whose copies were added for 14 days after it.
extension ActivityLog {
    /// Each old daily pin becomes a rule starting after now; it and its copies stay as plain pins.
    /// Copies the old code still owed by now are added. Running it again changes nothing.
    func migratingRepeats(at now: Date) -> ActivityLog {
        var log = self
        for mark in marks where mark.isDaily {
            log.marks += Self.owedCopies(of: mark, in: log.marks, at: now, calendar: calendar)
            // Derived from the old pin's id, so a second run finds it.
            let id = Self.occurrenceID(mark.id, day: 0xFFFF_FFFF)
            if !log.rules.contains(where: { $0.id == id }) {
                log.rules.append(ActivityRule(repeating: mark, id: id, after: now, calendar: calendar))
            }
        }
        log.marks = log.marks.map { mark in
            var plain = mark
            plain.repeats = nil
            return plain
        }
        return log
    }

    static func migrateRepeats(in defaults: UserDefaults = AppData.defaults, now: Date = .now) {
        let log = stored(in: defaults)
        guard log.marks.contains(where: \.isDaily) else { return }
        let migrated = log.migratingRepeats(at: now)
        defaults.encode(migrated.rules, rulesKey)
        defaults.encode(migrated.marks, key)
    }

    /// Copies due by now after the last one written; gaps before it were deleted on purpose.
    private static func owedCopies(of mark: ActivityMark, in marks: [ActivityMark], at now: Date, calendar: Calendar) -> [ActivityMark] {
        let times = (1...14).compactMap { calendar.date(byAdding: .day, value: $0, to: mark.time) }.filter { $0 <= now }
        let written = times.lastIndex { time in
            marks.contains { $0.tag == mark.tag && abs($0.time.timeIntervalSince(time)) < 120 }
        }
        return times[(written.map { $0 + 1 } ?? 0)...].map { ActivityMark(time: $0, tag: mark.tag) }
    }
}
