import Foundation

/// What a countdown shows: the largest non-zero unit big, the smaller units beneath; upper zero units hidden.
struct CountdownReadout: Equatable {
    enum Unit: Equatable { case days, hours, minutes, seconds }

    let unit: Unit
    let value: Int
    /// Label after the big value: "days", "h", "min", "sec".
    let label: String
    /// Smaller units: "05:32:10" (days), "32:10" (hours), "10s" (minutes), "" (seconds).
    let rest: String

    var compact: String { "\(value) \(label)" }

    /// Whole seconds are rounded up, so "1 sec" shows until the target and 0 only once it's reached.
    init(remaining: TimeInterval) {
        let total = remaining > 0 ? Int(remaining.rounded(.up)) : 0
        let d = total / 86_400, h = total % 86_400 / 3600, m = total % 3600 / 60, s = total % 60
        func two(_ n: Int) -> String { n < 10 ? "0\(n)" : "\(n)" }
        if d > 0 {
            (unit, value, label, rest) = (.days, d, d == 1 ? "day" : "days", "\(two(h)):\(two(m)):\(two(s))")
        } else if h > 0 {
            (unit, value, label, rest) = (.hours, h, "h", "\(two(m)):\(two(s))")
        } else if m > 0 {
            (unit, value, label, rest) = (.minutes, m, "min", "\(two(s))s")
        } else {
            (unit, value, label, rest) = (.seconds, s, "sec", "")
        }
    }
}
