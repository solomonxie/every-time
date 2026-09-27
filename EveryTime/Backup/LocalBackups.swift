import Foundation

/// Tier 1: zips in the Files-visible Documents folder, for undoing a mistake. Kept per `BackupRetention`.
enum LocalBackups {
    static var directory: URL { .documentsDirectory }

    private static let lastRunKey = "backup.local.lastAt"
    private static let fingerprintKey = "backup.local.fingerprint"

    /// On app-background: at most hourly, only if the snapshot changed.
    static func runIfDue(now: Date = .now) {
        let defaults = UserDefaults.standard
        let snapshot = BackupSnapshot.current()
        guard !snapshot.isEmpty else { return }
        let fingerprint = snapshot.fingerprint
        guard fingerprint != defaults.string(forKey: fingerprintKey) else { return }
        if let lastAt = defaults.object(forKey: lastRunKey) as? Date, now.timeIntervalSince(lastAt) < BackupSchedule.minimumGap { return }

        guard let archive = try? BackupArchive.make(snapshot), write(archive, named: BackupArchiveName.auto(now)) else { return }
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
        for name in BackupRetention.expired(listing(), now: now) {
            try? FileManager.default.removeItem(at: directory.appending(path: name))
        }
    }

    static func files() -> [BackupFile] {
        BackupArchiveName.newestFirst(listing()).map { name in
            let url = directory.appending(path: name)
            let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
            return BackupFile(name: name, url: url, size: size, isDownloaded: true)
        }
    }

    private static func listing() -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
    }

    /// Read back and compared, so a copy that "landed" is known to be restorable.
    private static func write(_ archive: Data, named name: String) -> Bool {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: name)
        guard (try? archive.write(to: url, options: .atomic)) != nil else { return false }
        return (try? Data(contentsOf: url)) == archive
    }
}
