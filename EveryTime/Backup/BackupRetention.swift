import Foundation

/// Which archives to keep: everything from the last 48 h, the newest of each day for 14 days,
/// the newest of each month for a year, and always the newest 3. Names that aren't ours are never touched.
enum BackupRetention {
    static let recent: TimeInterval = 48 * 3600
    static let dailyFor: TimeInterval = 14 * 86_400
    static let monthlyFor: TimeInterval = 366 * 86_400
    static let alwaysKept = 3

    static func expired<Names: Sequence<String>>(_ names: Names, now: Date = .now, calendar: Calendar = .current) -> [String] {
        var days = Set<DateComponents>(), months = Set<DateComponents>()
        return BackupArchiveName.newestFirst(names).enumerated().compactMap { index, name in
            guard let date = BackupArchiveName.date(of: name) else { return nil }
            let age = now.timeIntervalSince(date)
            let newestOfDay = days.insert(calendar.dateComponents([.year, .month, .day], from: date)).inserted
            let newestOfMonth = months.insert(calendar.dateComponents([.year, .month], from: date)).inserted
            let keep = index < alwaysKept || age < recent
                || (newestOfDay && age < dailyFor)
                || (newestOfMonth && age < monthlyFor)
            return keep ? nil : name
        }
    }
}
