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

/// Every user-data key in UserDefaults: `@Stored` values as embedded JSON, plain `@AppStorage` values as settings.
/// Keys are picked by prefix so new keys travel automatically.
struct BackupSnapshot {
    static let currentVersion = 1
    static let keyPrefixes = ["world.", "calendar.", "timers.", "sleep.", "tools.", "app.", "boards."]
    /// State of this device right now, never carried or replaced: a running nap, its system alarm, Health access.
    static let deviceKeys: Set<String> = ["sleep.nap.active", "sleep.nap.alarm.system", "sleep.health.asked"]
    static let fileName = "snapshot.json"

    var version = currentVersion
    var createdAt: Date?
    var appVersion = ""
    var entries: [String: Data] = [:]
    /// Plain values (Bool, number, String) as JSON fragments; written back as their native type.
    var settings: [String: Data] = [:]

    static func isBackedUp(_ key: String) -> Bool {
        keyPrefixes.contains { key.hasPrefix($0) } && !deviceKeys.contains(key)
    }

    static func storedKeys(in defaults: UserDefaults = .standard) -> [String] {
        defaults.dictionaryRepresentation().keys.filter(isBackedUp)
    }

    static func current(in defaults: UserDefaults = .standard) -> BackupSnapshot {
        var entries: [String: Data] = [:]
        var settings: [String: Data] = [:]
        for (key, value) in defaults.dictionaryRepresentation() where isBackedUp(key) {
            if let data = value as? Data {
                if json(data) != nil { entries[key] = data }
            } else if let plain = plain(value) {
                settings[key] = plain
            }
        }
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        return BackupSnapshot(createdAt: .now, appVersion: appVersion, entries: entries, settings: settings)
    }

    /// Replaces every backed-up `@Stored` key (absent ones fall back to their defaults) and writes the carried settings.
    /// Plain values the snapshot doesn't carry stay as they are.
    func apply(to defaults: UserDefaults = .standard) {
        for key in Self.storedKeys(in: defaults) where entries[key] == nil && defaults.object(forKey: key) is Data {
            defaults.removeObject(forKey: key)
        }
        for (key, data) in entries {
            defaults.set(data, forKey: key)
        }
        for (key, data) in settings {
            if let value = Self.json(data) { defaults.set(value, forKey: key) }
        }
    }

    var isEmpty: Bool {
        settings.isEmpty && !entries.values.contains { data in
            switch Self.json(data) {
            case let array as [Any]: !array.isEmpty
            case let object as [String: Any]: !object.isEmpty
            case nil: false
            default: true
            }
        }
    }

    /// Items in a user list (cities, events, logs…), as opposed to settings and tab pins the app writes itself.
    var hasUserContent: Bool {
        stats.contains { $0.count > 0 }
    }

    var fingerprint: String {
        let all = embeddedEntries.merging(settings.compactMapValues(Self.json)) { entry, _ in entry }
        let canonical = (try? JSONSerialization.data(withJSONObject: all, options: [.sortedKeys, .fragmentsAllowed])) ?? Data()
        return SHA256.hash(data: canonical).map { String(format: "%02x", $0) }.joined()
    }

    struct Stat: Identifiable, Equatable {
        let key: String
        let label: String
        let symbol: String
        let count: Int
        var id: String { key }
        var text: String { "\(count) \(label)" }
    }

    /// Item counts per kind of data, in a fixed order; kinds absent from the snapshot are left out.
    var stats: [Stat] {
        Self.countedKeys.compactMap { key, singular, plural, symbol in
            guard let data = entries[key], let array = Self.json(data) as? [Any] else { return nil }
            return Stat(key: key, label: array.count == 1 ? singular : plural, symbol: symbol, count: array.count)
        }
    }

    /// Stored values that aren't counted lists: tab bar, timer lengths, sleep profile…
    var settingsCount: Int {
        let counted = Set(stats.map(\.key))
        return entries.keys.filter { !counted.contains($0) }.count + settings.count
    }

    /// "4 cities · 2 lunar events · 12 LeetCode sessions · saved Sep 25, 2026"
    var summary: String {
        var parts = stats.filter { $0.count > 0 }.map(\.text)
        if settingsCount > 0 { parts.append("\(settingsCount) \(settingsCount == 1 ? "setting" : "settings")") }
        if let createdAt { parts.append("saved \(createdAt.formatted(date: .abbreviated, time: .omitted))") }
        return parts.joined(separator: " · ")
    }

    private static let countedKeys = [
        ("world.cities", "city", "cities", "globe"),
        ("calendar.lunar", "lunar event", "lunar events", "calendar"),
        ("calendar.since", "important event", "important events", "star.circle"),
        ("timers.countdowns", "countdown", "countdowns", "hourglass.bottomhalf.filled"),
        ("timers.leetcodeHistory", "LeetCode session", "LeetCode sessions", "chevron.left.forwardslash.chevron.right"),
        ("timers.workLog", "work session", "work sessions", "briefcase"),
        ("timers.activityLog", "activity mark", "activity marks", "hand.tap"),
        ("timers.feelings", "feeling", "feelings", "face.smiling"),
        ("sleep.naps", "nap", "naps", "moon.zzz"),
        ("sleep.jetlag.trips", "trip", "trips", "airplane"),
    ]

    // MARK: JSON

    func encoded() throws -> Data {
        var object: [String: Any] = [
            "version": version,
            "appVersion": appVersion,
            "entries": embeddedEntries,
        ]
        if !settings.isEmpty { object["settings"] = settings.compactMapValues(Self.json) }
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
        let plain = object["settings"] as? [String: Any] ?? [:]
        settings = plain
            .filter { Self.isBackedUp($0.key) && entries[$0.key] == nil }
            .compactMapValues(Self.plain)
    }

    init(createdAt: Date?, appVersion: String, entries: [String: Data], settings: [String: Data] = [:]) {
        self.createdAt = createdAt
        self.appVersion = appVersion
        self.entries = entries
        self.settings = settings
    }

    private var embeddedEntries: [String: Any] {
        entries.compactMapValues(Self.json)
    }

    private static func json(_ data: Data) -> Any? {
        try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
    }

    /// Bool, number or String as a JSON fragment; anything else (dates, arrays) isn't a setting.
    private static func plain(_ value: Any) -> Data? {
        guard value is NSNumber || value is String, JSONSerialization.isValidJSONObject([value]) else { return nil }
        return try? JSONSerialization.data(withJSONObject: value, options: .fragmentsAllowed)
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
