import Foundation
import Testing
@testable import EveryTime

private func json(_ text: String) -> Data { Data(text.utf8) }

private func snapshot(_ entries: [String: String], settings: [String: String] = [:], createdAt: Date? = nil) -> BackupSnapshot {
    BackupSnapshot(createdAt: createdAt, appVersion: "1.2.3", entries: entries.mapValues(json), settings: settings.mapValues(json))
}

struct BackupSnapshotTests {
    @Test func backsUpOnlyKnownPrefixes() {
        #expect(BackupSnapshot.isBackedUp("world.cities"))
        #expect(BackupSnapshot.isBackedUp("sleep.naps"))
        #expect(!BackupSnapshot.isBackedUp("AppleLanguages"))
        #expect(!BackupSnapshot.isBackedUp("worldcities"))
        #expect(!BackupSnapshot.isBackedUp("sleep.nap.alarm.system"))
        #expect(!BackupSnapshot.isBackedUp("sleep.nap.active"))
    }

    @Test func jsonRoundTrip() throws {
        let original = snapshot(["world.cities": #"[{"b":1,"a":"x"}]"#, "app.theme": #""dark""#, "sleep.on": "true"],
                                settings: ["app.tab": #""sleep""#, "sleep.nap.minutes": "20"],
                                createdAt: date(2026, 9, 25, 14, 2, 33))
        let decoded = try BackupSnapshot(json: original.encoded())
        #expect(decoded.version == BackupSnapshot.currentVersion)
        #expect(decoded.createdAt == original.createdAt)
        #expect(decoded.appVersion == "1.2.3")
        #expect(Set(decoded.entries.keys) == Set(original.entries.keys))
        #expect(decoded.settings == original.settings)
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
        #expect(!snapshot([:], settings: ["app.tab": #""sleep""#]).isEmpty)
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
        #expect(current.settings == ["app.string": json(#""plain""#)])

        snapshot(["world.cities": "[9]", "sleep.naps": "[]"]).apply(to: defaults)
        #expect(defaults.data(forKey: "world.cities") == json("[9]"))
        #expect(defaults.data(forKey: "sleep.naps") == json("[]"))
        #expect(defaults.object(forKey: "timers.leetcodeHistory") == nil)
        #expect(defaults.string(forKey: "app.string") == "plain")
        #expect(defaults.data(forKey: "unrelated") == json("[4]"))
    }

    @Test func applyKeepsPlainAppStorage() throws {
        let suite = "EveryTimeTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("world", forKey: "app.tab")
        defaults.set(20, forKey: "sleep.nap.minutes")
        defaults.set(true, forKey: "sleep.health.asked")
        defaults.set("old", forKey: "sleep.woke.dismissed")
        defaults.set("alarm-id", forKey: "sleep.nap.alarm.system")
        defaults.set(json("{}"), forKey: "sleep.nap.active")

        let carried = BackupSnapshot.current(in: defaults)
        #expect(Set(carried.settings.keys) == ["app.tab", "sleep.nap.minutes", "sleep.woke.dismissed"])
        #expect(carried.entries.isEmpty)

        snapshot(["world.cities": "[1]"], settings: ["app.tab": #""sleep""#, "sleep.nap.minutes": "30"]).apply(to: defaults)
        #expect(defaults.string(forKey: "app.tab") == "sleep")
        #expect(defaults.integer(forKey: "sleep.nap.minutes") == 30)
        #expect(defaults.bool(forKey: "sleep.health.asked"))
        #expect(defaults.string(forKey: "sleep.woke.dismissed") == "old")
        #expect(defaults.string(forKey: "sleep.nap.alarm.system") == "alarm-id")
        #expect(defaults.data(forKey: "sleep.nap.active") == json("{}"))
    }

    @Test func settingsRoundTripTheirType() throws {
        let suite = "EveryTimeTests.\(UUID().uuidString)"
        let source = try #require(UserDefaults(suiteName: suite))
        let target = try #require(UserDefaults(suiteName: suite + ".target"))
        defer { [suite, suite + ".target"].forEach { source.removePersistentDomain(forName: $0) } }
        source.set(true, forKey: "app.flag")
        source.set(45, forKey: "sleep.nap.minutes")
        source.set(1.5, forKey: "tools.ratio")
        source.set("nap", forKey: "sleep.kind")

        let restored = try BackupArchive.read(BackupArchive.make(BackupSnapshot.current(in: source)))
        restored.apply(to: target)
        #expect(target.object(forKey: "app.flag") as? Bool == true)
        #expect(target.integer(forKey: "sleep.nap.minutes") == 45)
        #expect(target.double(forKey: "tools.ratio") == 1.5)
        #expect(target.string(forKey: "sleep.kind") == "nap")
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
        let utc = date(2026, 9, 25, 14, 2, 33, in: .gmt)
        #expect(BackupArchiveName.daily(when) == "20260925-daily-every-time.zip")
        #expect(BackupArchiveName.base(when) == "20260925-daily-every-time")
        #expect(BackupArchiveName.before("import", at: utc) == "20260925140233Z-before-import-every-time.zip")
        #expect(BackupArchiveName.auto(utc) == "20260925140233Z-auto-every-time.zip")
    }

    @Test func namesOrderAcrossZones() {
        let tokyo = date(2026, 10, 16, 8, in: TimeZone(identifier: "Asia/Tokyo")!)
        let sanFrancisco = date(2026, 10, 15, 18, in: TimeZone(identifier: "America/Los_Angeles")!)
        let names = [BackupArchiveName.auto(tokyo), BackupArchiveName.auto(sanFrancisco)]
        #expect(BackupArchiveName.newestFirst(names).first == BackupArchiveName.auto(sanFrancisco))
        #expect(BackupArchiveName.date(of: names[0]) == tokyo)
        #expect(BackupArchiveName.date(of: names[1]) == sanFrancisco)
    }

    @Test func oldLocalNamesStillParse() {
        #expect(BackupArchiveName.date(of: "20260925140233-auto-every-time.zip") == when)
        #expect(BackupArchiveName.kind(of: "20260925140233Z-auto-every-time.zip") == "Automatic")
        #expect(!BackupArchiveName.isOurs("20260925Z-daily-every-time.zip"))
    }

    @Test func recognisesOwnNames() {
        #expect(BackupArchiveName.isOurs("20260925-daily-every-time.zip"))
        #expect(BackupArchiveName.isOurs("20260925140233-before-import-every-time.zip"))
        #expect(BackupArchiveName.isOurs("20260925140233Z-auto-every-time.zip"))
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

struct BackupRetentionTests {
    private let now = date(2026, 9, 26, 12)

    private func names(_ dates: [Date]) -> [String] { dates.map { BackupArchiveName.auto($0) } }

    @Test func autoNamesRoundTripTheirTime() {
        let when = date(2026, 9, 25, 14, 2, 33)
        #expect(BackupArchiveName.date(of: BackupArchiveName.auto(when)) == when)
        #expect(BackupArchiveName.kind(of: BackupArchiveName.auto(when)) == "Automatic")
        #expect(BackupArchiveName.kind(of: "20260925140233-before-import-every-time.zip") == "Before import")
        #expect(BackupArchiveName.kind(of: "20260925-daily-every-time.zip") == "Daily")
    }

    @Test func keepsEverythingRecent() {
        let hourly = names((0..<47).map { now.addingTimeInterval(-Double($0) * 3600) })
        #expect(BackupRetention.expired(hourly, now: now, calendar: gregorian()).isEmpty)
    }

    @Test func thinsOlderToOnePerDayThenPerMonth() {
        let calendar = gregorian()
        let morning = names((3..<20).map { calendar.date(byAdding: .day, value: -$0, to: date(2026, 9, 26, 9))! })
        let evening = names((3..<20).map { calendar.date(byAdding: .day, value: -$0, to: date(2026, 9, 26, 21))! })
        let expired = Set(BackupRetention.expired(morning + evening, now: now, calendar: calendar))
        // Within 14 days only the evening (newest) copy of each day stays; the newest 3 include one morning.
        #expect(expired.isSuperset(of: morning[1..<11]))
        #expect(!expired.contains(morning[0]))
        #expect(expired.isDisjoint(with: evening.prefix(11)))
        // Past 14 days September's newest is already kept, so older days go.
        #expect(expired.isSuperset(of: evening.suffix(from: 12)))
    }

    @Test func keepsNewestOfEachMonthForAYear() {
        let calendar = gregorian()
        let monthly = names((1...14).map { calendar.date(byAdding: .month, value: -$0, to: now)! })
        let expired = BackupRetention.expired(monthly, now: now, calendar: calendar)
        #expect(Set(expired) == Set(monthly.suffix(2)))
    }

    @Test func alwaysKeepsNewestThreeAndIgnoresForeignFiles() {
        let calendar = gregorian()
        let old = names((0..<3).map { calendar.date(byAdding: .year, value: -2, to: now)!.addingTimeInterval(-Double($0) * 86_400) })
        #expect(BackupRetention.expired(old + ["notes.zip"], now: now, calendar: calendar).isEmpty)
    }
}

struct BackupContentTests {
    @Test func settingsAloneAreNotUserContent() {
        #expect(!snapshot(["world.localIndex": "0", "app.tabs": "[]"]).hasUserContent)
        #expect(!snapshot(["app.tabs": #"["sleep","world","feeling"]"#, "sleep.cycle": #"{"usesHealth":true}"#],
                          settings: ["app.tab": #""sleep""#]).hasUserContent)
        #expect(!snapshot(["world.cities": "[]"]).hasUserContent)
        #expect(snapshot(["world.cities": #"[{"a":1}]"#]).hasUserContent)
        #expect(snapshot(["timers.feelings": "[1]"]).hasUserContent)
    }

    @Test func firstRunSkipsSettingsOnlyArchive() throws {
        #expect(!FirstRunRestore.acceptable(try BackupArchive.make(snapshot(["world.localIndex": "0"]))))
        // Fresh install: pinning Feeling writes a non-empty app.tabs on first appear.
        #expect(!FirstRunRestore.acceptable(try BackupArchive.make(snapshot(["app.tabs": #"["sleep","feeling"]"#]))))
        #expect(FirstRunRestore.acceptable(try BackupArchive.make(snapshot(["app.tabs": #"["sleep"]"#, "sleep.naps": "[1]"]))))
        #expect(!FirstRunRestore.acceptable(Data("nope".utf8)))
    }

    @Test func statsCountEachKindInOrder() {
        let stats = snapshot(["timers.countdowns": "[1,2,3]", "world.cities": "[1]", "sleep.naps": "[]", "app.tabs": #"["world"]"#]).stats
        #expect(stats.map(\.key) == ["world.cities", "timers.countdowns", "sleep.naps"])
        #expect(stats.map(\.text) == ["1 city", "3 countdowns", "0 naps"])
    }
}
