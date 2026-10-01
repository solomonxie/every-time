import Foundation
import Testing
@testable import EveryTime

struct DemoSeedTests {
    private let calendar = gregorian()
    private let now = date(2026, 10, 1, 15, 30)

    @Test func relativeDates() {
        #expect(DemoSeed.date("@today", now: now, calendar: calendar) == date(2026, 10, 1))
        #expect(DemoSeed.date("@today-1 23:40", now: now, calendar: calendar) == date(2026, 9, 30, 23, 40))
        #expect(DemoSeed.date("@today+12 09:05", now: now, calendar: calendar) == date(2026, 10, 13, 9, 5))
        #expect(DemoSeed.date("@now", now: now, calendar: calendar) == now)
        #expect(DemoSeed.date("@now-25m", now: now, calendar: calendar) == date(2026, 10, 1, 15, 5))
        #expect(DemoSeed.date("@now+3h", now: now, calendar: calendar) == date(2026, 10, 1, 18, 30))
        #expect(DemoSeed.date("@now-2d", now: now, calendar: calendar) == date(2026, 9, 29, 15, 30))
    }

    @Test(arguments: ["today", "@later", "@now 10:00", "@now-5", "@today-1h", "Tokyo"])
    func notDates(text: String) {
        #expect(DemoSeed.date(text, now: now, calendar: calendar) == nil)
    }

    @Test func resolvesNestedValuesTheWayJSONEncoderWritesDates() throws {
        let raw: [String: Any] = ["a": [["start": "@today 07:05", "name": "Tokyo"]]]
        let resolved = DemoSeed.resolve(raw, now: now, calendar: calendar)
        let data = try JSONSerialization.data(withJSONObject: resolved)
        struct Item: Decodable { let start: Date; let name: String }
        let decoded = try JSONDecoder().decode([String: [Item]].self, from: data)
        #expect(decoded["a"]?.first?.start == date(2026, 10, 1, 7, 5))
        #expect(decoded["a"]?.first?.name == "Tokyo")
    }

    @Test func bundledPresetDecodesIntoTheAppsModels() throws {
        let values = DemoSeed.load(now: .now)
        func decode<T: Decodable>(_ type: T.Type, _ key: String) throws -> T {
            let data = try #require(values[key] as? Data, "missing \(key)")
            return try JSONDecoder().decode(type, from: data)
        }
        #expect(try decode([WorldCity].self, WorldCity.storageKey).count >= 5)
        #expect(try decode([Nap].self, NapKey.naps).filter(\.isNight).count >= 7)
        #expect(try !decode([Trip].self, JetLagKey.trips).isEmpty)
        _ = try decode(JetLagProfile.self, JetLagKey.profile)
        #expect(try !decode([ActivityMark].self, ActivityLog.key).isEmpty)
        #expect(try !decode([Countdown].self, Countdown.storageKey).isEmpty)
        #expect(try !decode([LunarEvent].self, "calendar.lunar").isEmpty)
        #expect(try !decode([ImportantEvent].self, ImportantEvent.storageKey).isEmpty)
        #expect(try !decode([TimerSession].self, TimerStore.leetcodeHistoryKey).isEmpty)
        #expect(try !decode([WorkSpan].self, WorkLog.key).isEmpty)
        #expect(values[PastNights.key] as? Bool == true)
        for (key, value) in values {
            guard let data = value as? Data else { continue }
            #expect(!String(decoding: data, as: UTF8.self).contains("\"@"), "unresolved date in \(key)")
        }
    }

    @Test func demoStoreIsNotTheRealOne() {
        #expect(AppData.demoDefaults !== UserDefaults.standard)
        #expect(AppData.demoSuite != Bundle.main.bundleIdentifier)
    }
}
