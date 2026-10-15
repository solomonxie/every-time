import Foundation

/// Local hours every city should share; `end` before `start` wraps past midnight.
struct TargetHours: Codable, Equatable {
    var start = 8
    var end = 18

    static let work = TargetHours()
    static let awake = TargetHours(start: 7, end: 23)

    func contains(_ hour: Int) -> Bool {
        start < end ? (start..<end).contains(hour) : hour >= start || hour < end
    }
}

/// Spans where every zone's wall clock is inside the target hours.
/// Steps by 15 min: every real offset and DST jump is a multiple of it, so each step sits in one local hour everywhere.
enum OverlapFinder {
    static let step: TimeInterval = 15 * 60

    static func ranges(from start: Date, to end: Date, calendars: [Calendar], target: TargetHours) -> [Range<Date>] {
        guard !calendars.isEmpty, start < end else { return [] }
        var ranges: [Range<Date>] = []
        var instant = start
        while instant < end {
            let next = min(instant.addingTimeInterval(step), end)
            if calendars.allSatisfy({ target.contains($0.component(.hour, from: instant)) }) {
                if let last = ranges.last, last.upperBound == instant {
                    ranges[ranges.count - 1] = last.lowerBound..<next
                } else {
                    ranges.append(instant..<next)
                }
            }
            instant = next
        }
        return ranges
    }

    /// The calendar day around `date` in `day`'s zone, 23 h or 25 h on DST changes.
    static func ranges(onDayOf date: Date, in day: Calendar, calendars: [Calendar], target: TargetHours) -> [Range<Date>] {
        let start = day.startOfDay(for: date)
        guard let end = day.date(byAdding: .day, value: 1, to: start) else { return [] }
        return ranges(from: start, to: end, calendars: calendars, target: target)
    }
}
