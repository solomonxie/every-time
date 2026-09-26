import CryptoKit
import Foundation

enum BackupError: LocalizedError {
    case unreadable, notABackup, newerVersion, empty

    var errorDescription: String? {
        switch self {
        case .unreadable: "Couldn't read that file."
        case .notABackup: "This isn't an Every Time backup."
        case .newerVersion: "This backup is from a newer version of Every Time. Update the app, then import it again."
        case .empty: "This backup has nothing in it."
        }
    }
}

/// Every user-data key in UserDefaults, as embedded JSON. Keys are picked by prefix so new `@Stored` keys travel automatically.
struct BackupSnapshot {
    static let currentVersion = 1
    static let keyPrefixes = ["world.", "calendar.", "timers.", "sleep.", "tools.", "app."]
    static let fileName = "snapshot.json"

    var version = currentVersion
    var createdAt: Date?
    var appVersion = ""
    var entries: [String: Data] = [:]

    static func isBackedUp(_ key: String) -> Bool {
        keyPrefixes.contains { key.hasPrefix($0) }
    }

    static func storedKeys(in defaults: UserDefaults = .standard) -> [String] {
        defaults.dictionaryRepresentation().keys.filter(isBackedUp)
    }

    static func current(in defaults: UserDefaults = .standard) -> BackupSnapshot {
        let entries = defaults.dictionaryRepresentation()
            .filter { isBackedUp($0.key) }
            .compactMapValues { value -> Data? in
                guard let data = value as? Data, json(data) != nil else { return nil }
                return data
            }
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        return BackupSnapshot(createdAt: .now, appVersion: appVersion, entries: entries)
    }

    /// Replaces every backed-up key; keys absent from the snapshot fall back to their defaults.
    func apply(to defaults: UserDefaults = .standard) {
        for key in Self.storedKeys(in: defaults) where entries[key] == nil {
            defaults.removeObject(forKey: key)
        }
        for (key, data) in entries {
            defaults.set(data, forKey: key)
        }
    }

    var isEmpty: Bool {
        !entries.values.contains { data in
            switch Self.json(data) {
            case let array as [Any]: !array.isEmpty
            case let object as [String: Any]: !object.isEmpty
            case nil: false
            default: true
            }
        }
    }

    var fingerprint: String {
        let canonical = (try? JSONSerialization.data(withJSONObject: embeddedEntries, options: [.sortedKeys, .fragmentsAllowed])) ?? Data()
        return SHA256.hash(data: canonical).map { String(format: "%02x", $0) }.joined()
    }

    /// "4 cities · 2 lunar events · 12 LeetCode sessions · saved Sep 25, 2026"
    var summary: String {
        var parts: [String] = []
        var counted = Set<String>()
        for (key, singular, plural) in Self.countedKeys {
            guard let data = entries[key], let array = Self.json(data) as? [Any] else { continue }
            counted.insert(key)
            if !array.isEmpty { parts.append("\(array.count) \(array.count == 1 ? singular : plural)") }
        }
        let others = entries.keys.filter { !counted.contains($0) }.count
        if others > 0 { parts.append("\(others) \(others == 1 ? "setting" : "settings")") }
        if let createdAt { parts.append("saved \(createdAt.formatted(date: .abbreviated, time: .omitted))") }
        return parts.joined(separator: " · ")
    }

    private static let countedKeys = [
        ("world.cities", "city", "cities"),
        ("calendar.lunar", "lunar event", "lunar events"),
        ("calendar.since", "important event", "important events"),
        ("timers.leetcodeHistory", "LeetCode session", "LeetCode sessions"),
    ]

    // MARK: JSON

    func encoded() throws -> Data {
        var object: [String: Any] = [
            "version": version,
            "appVersion": appVersion,
            "entries": embeddedEntries,
        ]
        if let createdAt { object["createdAt"] = ISO8601DateFormatter().string(from: createdAt) }
        return try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    }

    /// Hand-written so fields added later stay optional for older files.
    init(json data: Data) throws {
        guard let object = Self.json(data) as? [String: Any], let version = object["version"] as? Int, version >= 1 else {
            throw BackupError.notABackup
        }
        guard version <= Self.currentVersion else { throw BackupError.newerVersion }
        self.version = version
        createdAt = (object["createdAt"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) }
        appVersion = object["appVersion"] as? String ?? ""
        let raw = object["entries"] as? [String: Any] ?? [:]
        entries = raw
            .filter { Self.isBackedUp($0.key) }
            .compactMapValues { try? JSONSerialization.data(withJSONObject: $0, options: .fragmentsAllowed) }
    }

    init(createdAt: Date?, appVersion: String, entries: [String: Data]) {
        self.createdAt = createdAt
        self.appVersion = appVersion
        self.entries = entries
    }

    private var embeddedEntries: [String: Any] {
        entries.compactMapValues(Self.json)
    }

    private static func json(_ data: Data) -> Any? {
        try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
    }
}

enum BackupArchive {
    static func make(_ snapshot: BackupSnapshot) throws -> Data {
        ZipArchive.write([.init(name: BackupSnapshot.fileName, data: try snapshot.encoded())])
    }

    /// Refuses newer versions and empty snapshots.
    static func read(_ archive: Data) throws -> BackupSnapshot {
        guard let json = ZipArchive.read(archive).first(where: { $0.name == BackupSnapshot.fileName })?.data else {
            throw BackupError.notABackup
        }
        let snapshot = try BackupSnapshot(json: json)
        guard !snapshot.isEmpty else { throw BackupError.empty }
        return snapshot
    }
}
