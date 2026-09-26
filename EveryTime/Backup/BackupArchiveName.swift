import Foundation

/// When, what for, whose: `20260925-daily-every-time.zip`, `20260925140233-before-import-every-time.zip`.
/// The date leads so the name is the sort order.
enum BackupArchiveName {
    static let suffix = "every-time"

    static func daily(_ date: Date = .now) -> String { base(date) + ".zip" }

    /// Without extension, for `.fileExporter`.
    static func base(_ date: Date = .now) -> String { "\(stamp(date, "yyyyMMdd"))-daily-\(suffix)" }

    static func before(_ operation: String, at date: Date = .now) -> String {
        "\(stamp(date, "yyyyMMddHHmmss"))-before-\(operation)-\(suffix).zip"
    }

    static func isOurs(_ name: String) -> Bool { rank(of: name) != nil }

    static func newestFirst<Names: Sequence<String>>(_ names: Names) -> [String] {
        names.filter(isOurs).sorted { rank(of: $0)! > rank(of: $1)! }
    }

    /// Leading digits padded to 14, so a day and a day-and-time compare as text.
    private static func rank(of name: String) -> String? {
        guard name.hasSuffix("-\(suffix).zip"), let digits = name.split(separator: "-").first,
              digits.allSatisfy(\.isNumber) else { return nil }
        switch digits.count {
        case 14: return String(digits)
        case 8: return digits + "000000"
        default: return nil
        }
    }

    private static func stamp(_ date: Date, _ format: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}
