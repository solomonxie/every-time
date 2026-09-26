import Foundation

/// Why the iCloud folder can't be written to. All arrive as the same nil container.
enum CloudDriveStatus: Equatable {
    case ready
    /// Build signed without the capability — nothing the user can do.
    case notEntitled
    /// Signed out, or iCloud Drive off. The only state with directions.
    case driveOff
    /// Entitled and signed in, container not there yet.
    case notReady
}

enum CloudDriveError: LocalizedError {
    case unavailable
    var errorDescription: String? { "This device's iCloud folder isn't available." }
}

/// Tier 2: `Files → iCloud Drive → Every Time`. Archives only, one per day, latest 10 kept.
/// Every call touches the filesystem or iCloud's daemon, so all are nonisolated async (off the main actor).
enum CloudDrive {
    static let containerID = "iCloud.com.solomonxie.everytime"
    static let keptArchives = 10

    static func status() async -> CloudDriveStatus {
        if documentsURL() != nil { return .ready }
        // Entitlement first: without it ubiquityIdentityToken reads nil, same as signed out.
        guard BuildSigning.hasCloudEntitlement else { return .notEntitled }
        guard FileManager.default.ubiquityIdentityToken != nil else { return .driveOff }
        return .notReady
    }

    static func write(_ archive: Data) async throws {
        guard let documents = documentsURL() else { throw CloudDriveError.unavailable }
        try archive.write(to: documents.appending(path: BackupArchiveName.daily()), options: .atomic)
        prune(in: documents)
    }

    /// Newest acceptable archive, waiting for iCloud to download placeholders (always the case on a fresh install).
    static func latestBackup(
        timeout: TimeInterval = 30,
        acceptable: @Sendable (Data) -> Bool
    ) async throws -> Data? {
        guard let documents = documentsURL() else { throw CloudDriveError.unavailable }
        let deadline = Date().addingTimeInterval(timeout)
        for name in BackupArchiveName.newestFirst(listing(documents).keys) {
            guard let archive = await read(documents.appending(path: name), until: deadline) else { continue }
            if acceptable(archive) { return archive }
        }
        return nil
    }

    private static func read(_ url: URL, until deadline: Date) async -> Data? {
        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        repeat {
            if let data = try? Data(contentsOf: url), !data.isEmpty { return data }
            try? await Task.sleep(for: .milliseconds(500))
        } while Date() < deadline && !Task.isCancelled
        return nil
    }

    private static func prune(in documents: URL) {
        let onDisk = listing(documents)
        let newest = BackupArchiveName.newestFirst(onDisk.keys)
        for name in newest.dropFirst(keptArchives) {
            guard let fileName = onDisk[name] else { continue }
            try? FileManager.default.removeItem(at: documents.appending(path: fileName))
        }
    }

    /// Real name → name on disk. Undownloaded files sit under `.<name>.icloud`.
    private static func listing(_ documents: URL) -> [String: String] {
        let listed = (try? FileManager.default.contentsOfDirectory(atPath: documents.path)) ?? []
        return Dictionary(listed.map { (realName(ofPlaceholder: $0), $0) }, uniquingKeysWith: { first, _ in first })
    }

    private static func realName(ofPlaceholder name: String) -> String {
        guard name.hasPrefix("."), name.hasSuffix(".icloud") else { return name }
        return String(name.dropFirst().dropLast(".icloud".count))
    }

    private static func documentsURL() -> URL? {
        guard let container = FileManager.default.url(forUbiquityContainerIdentifier: containerID) else { return nil }
        let documents = container.appending(path: "Documents", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
        return documents
    }
}

/// Reads the iCloud entitlement from the embedded provisioning profile (`SecTaskCopyValueForEntitlement` isn't in the iOS SDK).
private enum BuildSigning {
    static let hasCloudEntitlement: Bool = {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let profile = try? Data(contentsOf: url)
        else { return true } // App Store builds ship no profile.
        guard let entitlements = plist(in: profile)?["Entitlements"] as? [String: Any],
              let containers = entitlements["com.apple.developer.ubiquity-container-identifiers"] as? [String]
        else { return false }
        return !containers.isEmpty
    }()

    private static func plist(in profile: Data) -> [String: Any]? {
        guard let start = profile.range(of: Data("<?xml".utf8)),
              let end = profile.range(of: Data("</plist>".utf8), in: start.upperBound..<profile.endIndex)
        else { return nil }
        let xml = Data(profile[start.lowerBound..<end.upperBound])
        return (try? PropertyListSerialization.propertyList(from: xml, format: nil)) as? [String: Any]
    }
}
