import Foundation

/// Fresh install: pull the newest iCloud archive with user content back once, silently.
/// Retries on later launches while the container isn't ready or archives haven't downloaded.
/// "Content" = items in the user lists (`BackupSnapshot.stats`); settings and tab pins the app writes on launch don't count.
enum FirstRunRestore {
    private static let doneKey = "backup.icloud.didRestore"

    static var isDone: Bool { UserDefaults.standard.bool(forKey: doneKey) }

    static func acceptable(_ archive: Data) -> Bool {
        (try? BackupArchive.read(archive))?.hasUserContent == true
    }

    @MainActor
    static func runIfNeeded() async {
        guard !isDone else { return }
        guard !hasLocalContent else { return finish() }
        guard await CloudDrive.status() == .ready else { return }
        let archive = try? await CloudDrive.latestBackup { acceptable($0) }
        // Re-checked: the user may have added data while iCloud was downloading.
        guard !hasLocalContent else { return finish() }
        guard let archive, let snapshot = try? BackupArchive.read(archive) else {
            if (try? await CloudDrive.files())?.isEmpty == true { finish() }
            return
        }
        snapshot.apply()
        finish()
        AutoBackup.shared.enableAfterRestore()
    }

    private static var hasLocalContent: Bool { BackupSnapshot.current().hasUserContent }

    private static func finish() {
        UserDefaults.standard.set(true, forKey: doneKey)
    }
}
