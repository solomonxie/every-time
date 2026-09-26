import Foundation

/// Tier 1: zips in the Files-visible Documents folder, for undoing a mistake. Never a destination, never offered to restore from.
enum LocalBackups {
    static let maximumAge: TimeInterval = 7 * 24 * 60 * 60
    static var directory: URL { .documentsDirectory }

    private static let lastRunKey = "backup.local.lastAt"
    private static let fingerprintKey = "backup.local.fingerprint"

    /// On app-background: at most daily, only if the snapshot changed.
    static func runIfDue() {
        let defaults = UserDefaults.standard
        let snapshot = BackupSnapshot.current()
        guard !snapshot.isEmpty else { return }
        let fingerprint = snapshot.fingerprint
        guard fingerprint != defaults.string(forKey: fingerprintKey) else { return }
        if let lastAt = defaults.object(forKey: lastRunKey) as? Date, Calendar.current.isDateInToday(lastAt) { return }

        guard let archive = try? BackupArchive.make(snapshot), write(archive, named: BackupArchiveName.daily()) else { return }
        defaults.set(Date.now, forKey: lastRunKey)
        defaults.set(fingerprint, forKey: fingerprintKey)
        prune()
    }

    /// Before an import or restore. True when there's nothing to keep or the copy landed.
    @discardableResult
    static func writeBefore(_ operation: String) -> Bool {
        let snapshot = BackupSnapshot.current()
        guard !snapshot.isEmpty else { return true }
        guard let archive = try? BackupArchive.make(snapshot) else { return false }
        return write(archive, named: BackupArchiveName.before(operation))
    }

    static func prune(now: Date = .now) {
        let listed = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        for url in listed.filter(BackupArchiveName.isOurs).map({ directory.appending(path: $0) }) {
            let modifiedAt = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            guard let modifiedAt, now.timeIntervalSince(modifiedAt) > maximumAge else { continue }
            try? FileManager.default.removeItem(at: url)
        }
    }

    private static func write(_ archive: Data, named name: String) -> Bool {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (try? archive.write(to: directory.appending(path: name), options: .atomic)) != nil
    }
}
