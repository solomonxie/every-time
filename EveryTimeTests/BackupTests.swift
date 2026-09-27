import Foundation
import Testing
@testable import EveryTime

private func json(_ text: String) -> Data { Data(text.utf8) }

private func snapshot(_ entries: [String: String], createdAt: Date? = nil) -> BackupSnapshot {
    BackupSnapshot(createdAt: createdAt, appVersion: "1.2.3", entries: entries.mapValues(json))
}

struct BackupSnapshotTests {
    @Test func backsUpOnlyKnownPrefixes() {
        #expect(BackupSnapshot.isBackedUp("world.cities"))
        #expect(BackupSnapshot.isBackedUp("sleep.naps"))
        #expect(!BackupSnapshot.isBackedUp("AppleLanguages"))
        #expect(!BackupSnapshot.isBackedUp("worldcities"))
    }

    @Test func jsonRoundTrip() throws {
        let original = snapshot(["world.cities": #"[{"b":1,"a":"x"}]"#, "app.theme": #""dark""#, "sleep.on": "true"],
                                createdAt: date(2026, 9, 25, 14, 2, 33))
        let decoded = try BackupSnapshot(json: original.encoded())
        #expect(decoded.version == BackupSnapshot.currentVersion)
        #expect(decoded.createdAt == original.createdAt)
        #expect(decoded.appVersion == "1.2.3")
        #expect(Set(decoded.entries.keys) == Set(original.entries.keys))
        #expect(decoded.fingerprint == original.fingerprint)
    }

    @Test func fingerprintIgnoresKeyOrderButNotValues() {
        let a = snapshot(["world.cities": #"{"a":1,"b":2}"#])
        let b = snapshot(["world.cities": #"{"b":2,"a":1}"#])
        let c = snapshot(["world.cities": #"{"a":1,"b":3}"#])
        #expect(a.fingerprint == b.fingerprint)
        #expect(a.fingerprint != c.fingerprint)
    }

    @Test func dropsUnknownKeysAndToleratesMissingFields() throws {
        let decoded = try BackupSnapshot(json: json(#"{"version":1,"entries":{"world.cities":[1],"other":2}}"#))
        #expect(Array(decoded.entries.keys) == ["world.cities"])
        #expect(decoded.createdAt == nil)
        #expect(decoded.appVersion == "")
    }

    @Test(arguments: [#"{"entries":{}}"#, #"{"version":0}"#, "[]", "not json"])
    func rejectsNonBackups(_ text: String) {
        #expect(throws: BackupError.notABackup) { try BackupSnapshot(json: json(text)) }
    }

    @Test func rejectsNewerVersion() {
        #expect(throws: BackupError.newerVersion) {
            try BackupSnapshot(json: json(#"{"version":\#(BackupSnapshot.currentVersion + 1)}"#))
        }
    }

    @Test func emptiness() {
        #expect(snapshot([:]).isEmpty)
        #expect(snapshot(["world.cities": "[]", "app.prefs": "{}"]).isEmpty)
        #expect(!snapshot(["world.cities": "[1]"]).isEmpty)
        #expect(!snapshot(["app.flag": "false"]).isEmpty)
    }

    @Test func summaryCountsListsThenSettings() {
        let summary = snapshot(["world.cities": "[1,2]", "calendar.lunar": "[1]", "calendar.since": "[]",
                                "sleep.a": "1", "app.b": "2"]).summary
        #expect(summary == "2 cities · 1 lunar event · 2 settings")
        #expect(snapshot(["app.b": "2"], createdAt: date(2026, 9, 25)).summary.hasPrefix("1 setting · saved "))
    }

    @Test func currentAndApplyUseDefaults() throws {
        let suite = "EveryTimeTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(json("[1,2]"), forKey: "world.cities")
        defaults.set(json("[3]"), forKey: "timers.leetcodeHistory")
        defaults.set(Data([0xFF]), forKey: "app.binary")
        defaults.set("plain", forKey: "app.string")
        defaults.set(json("[4]"), forKey: "unrelated")

        let current = BackupSnapshot.current(in: defaults)
        #expect(Set(current.entries.keys) == ["world.cities", "timers.leetcodeHistory"])

        snapshot(["world.cities": "[9]", "sleep.naps": "[]"]).apply(to: defaults)
        #expect(defaults.data(forKey: "world.cities") == json("[9]"))
        #expect(defaults.data(forKey: "sleep.naps") == json("[]"))
        #expect(defaults.object(forKey: "timers.leetcodeHistory") == nil)
        #expect(defaults.object(forKey: "app.string") == nil)
        #expect(defaults.data(forKey: "unrelated") == json("[4]"))
    }
}

struct BackupArchiveTests {
    @Test func roundTrip() throws {
        let original = snapshot(["world.cities": "[1]"], createdAt: date(2026, 9, 25))
        let restored = try BackupArchive.read(BackupArchive.make(original))
        #expect(restored.fingerprint == original.fingerprint)
        #expect(restored.createdAt == original.createdAt)
    }

    @Test func refusesEmptyAndForeignArchives() throws {
        #expect(throws: BackupError.empty) { try BackupArchive.read(BackupArchive.make(snapshot(["world.cities": "[]"]))) }
        #expect(throws: BackupError.notABackup) { try BackupArchive.read(Data("nope".utf8)) }
        let other = ZipArchive.write([.init(name: "other.json", data: json("{}"))])
        #expect(throws: BackupError.notABackup) { try BackupArchive.read(other) }
    }
}

struct ZipArchiveTests {
    @Test func roundTripsEntries() {
        let entries: [ZipArchive.Entry] = [.init(name: "a.json", data: json("[1]")),
                                           .init(name: "dir/ü.txt", data: Data()),
                                           .init(name: "b.bin", data: Data((0...255).map(UInt8.init)))]
        let read = ZipArchive.read(ZipArchive.write(entries))
        #expect(read.map(\.name) == entries.map(\.name))
        #expect(read.map(\.data) == entries.map(\.data))
    }

    @Test func writesStandardHeaders() {
        let bytes = [UInt8](ZipArchive.write([.init(name: "x", data: Data("123456789".utf8))]))
        #expect(Array(bytes[0..<4]) == [0x50, 0x4B, 0x03, 0x04])
        #expect(Array(bytes[14..<18]) == [0x26, 0x39, 0xF4, 0xCB])
        #expect(Array(bytes[(bytes.count - 22)..<(bytes.count - 18)]) == [0x50, 0x4B, 0x05, 0x06])
    }

    @Test func stopsAtTruncatedEntry() {
        let archive = ZipArchive.write([.init(name: "a", data: json("[1]")), .init(name: "b", data: json("[2]"))])
        #expect(ZipArchive.read(archive.prefix(40)).map(\.name) == ["a"])
        #expect(ZipArchive.read(Data()).isEmpty)
    }
}

struct BackupArchiveNameTests {
    private let when = gregorian(.current).date(from: DateComponents(year: 2026, month: 9, day: 25, hour: 14, minute: 2, second: 33))!

    @Test func names() {
        #expect(BackupArchiveName.daily(when) == "20260925-daily-every-time.zip")
        #expect(BackupArchiveName.base(when) == "20260925-daily-every-time")
        #expect(BackupArchiveName.before("import", at: when) == "20260925140233-before-import-every-time.zip")
    }

    @Test func recognisesOwnNames() {
        #expect(BackupArchiveName.isOurs("20260925-daily-every-time.zip"))
        #expect(BackupArchiveName.isOurs("20260925140233-before-import-every-time.zip"))
        #expect(!BackupArchiveName.isOurs("2026-daily-every-time.zip"))
        #expect(!BackupArchiveName.isOurs("20260925-daily-every-time.json"))
        #expect(!BackupArchiveName.isOurs("backup.zip"))
    }

    @Test func newestFirstMixesDaysAndTimes() {
        let names = ["20260924-daily-every-time.zip", "notes.txt", "20260925-daily-every-time.zip",
                     "20260924230000-before-import-every-time.zip", "20260925000001-before-restore-every-time.zip"]
        #expect(BackupArchiveName.newestFirst(names) == ["20260925000001-before-restore-every-time.zip",
                                                         "20260925-daily-every-time.zip",
                                                         "20260924230000-before-import-every-time.zip",
                                                         "20260924-daily-every-time.zip"])
    }
}
