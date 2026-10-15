import Foundation

/// When, what for, whose: `20260925140233Z-auto-every-time.zip`, `20260925140233Z-before-import-every-time.zip` (UTC),
/// `20260925-daily-every-time.zip` (exports and older automatic copies, local day).
/// Older names without the `Z` are local time. The date leads; order comes from the parsed instant.
enum BackupArchiveName {
    static let suffix = "every-time"

    static func daily(_ date: Date = .now) -> String { base(date) + ".zip" }

    /// Without extension, for `.fileExporter`.
    static func base(_ date: Date = .now) -> String { "\(stamp(date, "yyyyMMdd"))-daily-\(suffix)" }

    static func auto(_ date: Date = .now) -> String {
        "\(utcStamp(date))-auto-\(suffix).zip"
    }

    static func before(_ operation: String, at date: Date = .now) -> String {
        "\(utcStamp(date))-before-\(operation)-\(suffix).zip"
    }

    static func isOurs(_ name: String) -> Bool { date(of: name) != nil }

    static func newestFirst<Names: Sequence<String>>(_ names: Names) -> [String] {
        names.compactMap { name in date(of: name).map { (name, $0) } }
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0 > $1.0 }
            .map(\.0)
    }

    /// A day alone counts from its local midnight.
    static func date(of name: String) -> Date? {
        guard name.hasSuffix("-\(suffix).zip"), let stamp = name.split(separator: "-").first else { return nil }
        let utc = stamp.hasSuffix("Z")
        let digits = utc ? stamp.dropLast() : stamp
        guard digits.allSatisfy(\.isNumber) else { return nil }
        switch digits.count {
        case 14: return formatter("yyyyMMddHHmmss", utc: utc).date(from: String(digits))
        case 8 where !utc: return formatter("yyyyMMdd").date(from: String(digits))
        default: return nil
        }
    }

    /// "Automatic", "Before import", "Daily".
    static func kind(of name: String) -> String {
        let words = name.split(separator: "-").dropFirst().dropLast(suffix.split(separator: "-").count)
        return (words.first == "auto" ? "Automatic" : words.joined(separator: " ")).capitalizedFirst
    }

    private static func stamp(_ date: Date, _ format: String) -> String {
        formatter(format).string(from: date)
    }

    private static func utcStamp(_ date: Date) -> String {
        formatter("yyyyMMddHHmmss", utc: true).string(from: date) + "Z"
    }

    private static func formatter(_ format: String, utc: Bool = false) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        if utc { formatter.timeZone = .gmt }
        formatter.isLenient = true
        formatter.dateFormat = format
        return formatter
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
