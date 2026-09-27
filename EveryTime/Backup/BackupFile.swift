import Foundation

/// One archive in a backup folder, as listed (contents read on demand).
struct BackupFile: Identifiable, Hashable {
    let name: String
    let url: URL
    let size: Int?
    let isDownloaded: Bool

    var id: String { name }
    var date: Date? { BackupArchiveName.date(of: name) }
    var kind: String { BackupArchiveName.kind(of: name) }
}

enum BackupSchedule {
    /// Changes are saved at most this often; each save is its own file, so none overwrites another.
    static let minimumGap: TimeInterval = 3600
}
