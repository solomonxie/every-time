import UIKit

/// The iCloud Drive switch. Daily, only if changed; the fingerprint is recorded only after a successful write.
@MainActor
final class AutoBackup: ObservableObject {
    static let shared = AutoBackup()

    private static let enabledKey = "backup.icloud"
    private static let lastAtKey = "backup.icloud.lastAt"
    private static let fingerprintKey = "backup.icloud.fingerprint"

    /// Flip-on backs up at once, so the row itself answers "did that work?".
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey)
            guard isEnabled, !oldValue else { return }
            Task { await backUp() }
        }
    }

    /// nil while the first check runs.
    @Published private(set) var status: CloudDriveStatus?
    @Published private(set) var lastBackupAt: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var isBackingUp = false

    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        lastBackupAt = UserDefaults.standard.object(forKey: Self.lastAtKey) as? Date
    }

    /// Re-checked on every foreground: the fix for a blocked row happens in the Settings app.
    func refresh() async {
        status = await CloudDrive.status()
        await backUpIfDue()
    }

    func backUpInBackground() {
        let task = UIApplication.shared.beginBackgroundTask()
        Task {
            await backUpIfDue()
            UIApplication.shared.endBackgroundTask(task)
        }
    }

    /// After a first-run restore, unless the user already chose.
    func enableAfterRestore() {
        guard UserDefaults.standard.object(forKey: Self.enabledKey) == nil else { return }
        isEnabled = true
    }

    private func backUpIfDue() async {
        guard isEnabled else { return }
        let snapshot = BackupSnapshot.current()
        guard snapshot.fingerprint != UserDefaults.standard.string(forKey: Self.fingerprintKey) else { return }
        if let lastBackupAt, Calendar.current.isDateInToday(lastBackupAt) { return }
        await backUp(snapshot)
    }

    private func backUp(_ snapshot: BackupSnapshot = .current()) async {
        guard !isBackingUp, !snapshot.isEmpty else { return }
        isBackingUp = true
        defer { isBackingUp = false }
        do {
            try await CloudDrive.write(try BackupArchive.make(snapshot))
            lastBackupAt = .now
            lastError = nil
            UserDefaults.standard.set(lastBackupAt, forKey: Self.lastAtKey)
            UserDefaults.standard.set(snapshot.fingerprint, forKey: Self.fingerprintKey)
        } catch is CloudDriveError {
            // Not a failure: the row already names the state.
            status = await CloudDrive.status()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }
}
