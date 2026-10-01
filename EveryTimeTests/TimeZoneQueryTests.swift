import Foundation
import Testing
@testable import EveryTime

struct TimeZoneQueryTests {
    private func names(_ query: String) -> [String] {
        TimeZoneQuery.matches(query).map { "\($0.name)|\($0.timeZoneIdentifier)" }
    }

    static let offsetCases: [(String, String, Int)] = [
        ("UTC+8", "UTC+8", 8 * 3600),
        ("utc +8", "UTC+8", 8 * 3600),
        ("GMT-5", "GMT−5", -5 * 3600),
        ("UTC−3", "UTC−3", -3 * 3600),
        ("UTC+5:30", "UTC+5:30", 19_800),
        ("+0530", "UTC+5:30", 19_800),
        ("UTC-09:30", "UTC−9:30", -34_200),
        ("UTC+14", "UTC+14", 14 * 3600),
        ("UTC", "UTC", 0),
        ("gmt", "GMT", 0),
    ]

    @Test(arguments: offsetCases)
    func offsets(query: String, name: String, seconds: Int) throws {
        let city = try #require(TimeZoneQuery.offset(query))
        #expect(city.name == name)
        #expect(city.timeZone.secondsFromGMT() == seconds)
        #expect(TimeZone(identifier: city.timeZoneIdentifier) != nil)
        #expect(TimeZoneQuery.isFixed(city))
    }

    @Test(arguments: ["UTC+15", "UTC-13", "UTC+5:75", "8", "Zurich", "", "UTC+", "GMT8"])
    func notOffsets(query: String) {
        #expect(TimeZoneQuery.offset(query) == nil)
    }

    @Test func abbreviationGivesRegionAndFixedZone() {
        #expect(names("PST") == ["Pacific Time|America/Los_Angeles", "PST|GMT-0800"])
        #expect(names("est") == ["Eastern Time|America/New_York", "EST|GMT-0500"])
        #expect(names("CET") == ["Central European Time|Europe/Paris", "CET|GMT+0100"])
        #expect(names("PT") == ["Pacific Time|America/Los_Angeles"])
    }

    @Test func ambiguousAbbreviationListsEveryMeaning() {
        #expect(names("CST") == ["Central Time|America/Chicago", "CST|GMT-0600", "China Time|Asia/Shanghai", "CST|GMT+0800"])
        #expect(names("IST").contains("India Time|Asia/Kolkata"))
        #expect(names("IST").contains("Israel Time|Asia/Jerusalem"))
    }

    @Test func zoneNamesMatchByWordStart() {
        #expect(names("central eu") == ["Central European Time|Europe/Paris", "CET|GMT+0100", "CEST|GMT+0200"])
        #expect(names("pacific").first == "Pacific Time|America/Los_Angeles")
        #expect(names("estern").isEmpty)
    }

    @Test func ianaIdentifiersInAnyCase() {
        #expect(names("Asia/Shanghai") == ["Shanghai|Asia/Shanghai"])
        #expect(names("asia/kolkata") == ["Kolkata|Asia/Kolkata"])
        #expect(names("america/new_york") == ["New York|America/New_York"])
        #expect(names("Etc/GMT+8") == ["UTC−8|Etc/GMT+8"])
    }

    @Test func plainTextIsNotAZone() {
        #expect(TimeZoneQuery.matches("Lon").isEmpty)
        #expect(TimeZoneQuery.matches("  ").isEmpty)
    }

    @Test func everyAbbreviationPointsAtARealZone() {
        for entry in TimeZoneQuery.table {
            #expect(TimeZone(identifier: entry.zone) != nil, "\(entry.code) → \(entry.zone)")
        }
    }

    @Test func fixedZonesSurviveARoundTrip() throws {
        let city = try #require(TimeZoneQuery.offset("UTC+5:45"))
        let decoded = try JSONDecoder().decode(WorldCity.self, from: JSONEncoder().encode(city))
        #expect(decoded.timeZone.secondsFromGMT() == 20_700)
        #expect(CityPickerView.detail(decoded) == "UTC+5:45 · no DST")
    }
}
