import Foundation
import Testing
@testable import EveryTime

struct WorldTests {
    private let london = WorldCity(timeZoneIdentifier: "Europe/London")

    private func calendars(_ ids: String...) -> [Calendar] {
        ids.map { gregorian(TimeZone(identifier: $0)!) }
    }

    @Test func localZoneCityHasUniqueRow() throws {
        let rows = TimelineRow.rows(cities: [london], local: london, localIndex: 0)
        #expect(Set(rows.map(\.id)).count == rows.count)

        let down = try #require(TimelineRow.move(TimelineRow.localID, onto: london.id, cities: [london], localIndex: 0))
        #expect(down.cities == [london])
        #expect(down.localIndex == 1)

        let up = try #require(TimelineRow.move(london.id, onto: TimelineRow.localID, cities: [london], localIndex: 1))
        #expect(up.cities == [london])
        #expect(up.localIndex == 0)
    }

    @Test func migratesExcludedLocalIDOnce() throws {
        let suite = "EveryTimeTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.encode([london], WorldCity.storageKey)
        defaults.encode(["Asia/Tokyo", "Europe/Berlin"], TimelineRow.excludedKey)

        TimelineRow.migrateLocalID(in: defaults, oldID: "Asia/Tokyo")
        #expect(defaults.decoded(TimelineRow.excludedKey) == ["Europe/Berlin", TimelineRow.localID])

        defaults.encode(["Europe/Berlin"], TimelineRow.excludedKey)
        TimelineRow.migrateLocalID(in: defaults, oldID: "Europe/Berlin")
        #expect(defaults.decoded(TimelineRow.excludedKey) == ["Europe/Berlin"])
    }

    @Test func migrationKeepsSavedCityInLocalZone() throws {
        let suite = "EveryTimeTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.encode([london], WorldCity.storageKey)
        defaults.encode([london.id], TimelineRow.excludedKey)

        TimelineRow.migrateLocalID(in: defaults, oldID: london.id)
        #expect(defaults.decoded(TimelineRow.excludedKey) == [london.id, TimelineRow.localID])
    }

    @Test func overlapHalfHourZone() {
        let tz = TimeZone(identifier: "Europe/London")!
        let day = date(2026, 7, 1, 12, in: tz)
        let kolkata = OverlapFinder.ranges(onDayOf: day, in: gregorian(tz), calendars: calendars("Europe/London", "Asia/Kolkata"),
                                           target: .work)
        #expect(kolkata == [date(2026, 7, 1, 8, in: tz)..<date(2026, 7, 1, 13, 30, in: tz)])

        let kathmandu = OverlapFinder.ranges(onDayOf: day, in: gregorian(tz), calendars: calendars("Europe/London", "Asia/Kathmandu"),
                                             target: .work)
        #expect(kathmandu == [date(2026, 7, 1, 8, in: tz)..<date(2026, 7, 1, 13, 15, in: tz)])
    }

    private func hours(_ ranges: [Range<Date>]) -> Double {
        ranges.reduce(0) { $0 + $1.upperBound.timeIntervalSince($1.lowerBound) } / 3600
    }

    @Test func overlapCoversWholeDstDay() {
        let ny = gregorian(newYork)
        let allDay = TargetHours(start: 0, end: 0)
        let spring = OverlapFinder.ranges(onDayOf: date(2026, 3, 8, 12, in: newYork), in: ny, calendars: [ny], target: allDay)
        #expect(spring == [date(2026, 3, 8, in: newYork)..<date(2026, 3, 9, in: newYork)])
        #expect(hours(spring) == 23)

        let fall = OverlapFinder.ranges(onDayOf: date(2026, 11, 1, 12, in: newYork), in: ny, calendars: [ny], target: allDay)
        #expect(fall.count == 1)
        #expect(hours(fall) == 25)

        let late = OverlapFinder.ranges(onDayOf: date(2026, 11, 1, 12, in: newYork), in: ny, calendars: [ny],
                                        target: TargetHours(start: 22, end: 0))
        #expect(late == [date(2026, 11, 1, 22, in: newYork)..<date(2026, 11, 2, in: newYork)])
    }

    @Test func overlapNeedsACity() {
        #expect(OverlapFinder.ranges(from: date(2026, 7, 1), to: date(2026, 7, 2), calendars: [], target: .work).isEmpty)
    }
}
