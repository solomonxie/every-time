import Foundation

/// Fresh install: pull the newest iCloud archive back once, silently. Retries on later launches while the container isn't ready.
/// "Fresh" = no lists with items yet; small values the app writes on launch (selected tab, scroll spot) don't count.
enum FirstRunRestore {
    private static let doneKey = "backup.icloud.didRestore"

    @MainActor
    static func runIfNeeded() async {
        guard shouldRun else { return }
        guard await CloudDrive.status() == .ready else { return }
        let archive = try? await CloudDrive.latestBackup { (try? BackupArchive.read($0)) != nil }
        // Re-checked: the user may have added data while iCloud was downloading.
        guard shouldRun, let archive, let snapshot = try? BackupArchive.read(archive) else { return }
        snapshot.apply()
        UserDefaults.standard.set(true, forKey: doneKey)
        AutoBackup.shared.enableAfterRestore()
    }

    private static var shouldRun: Bool {
        !UserDefaults.standard.bool(forKey: doneKey) && !BackupSnapshot.current().hasUserContent
    }
}
