import Foundation
import Testing
@testable import EveryTime

struct SunPositionTests {
    private let utc = TimeZone(identifier: "UTC")!

    @Test func overheadAtSolsticesAndEquinox() {
        let june = SunPosition(at: date(2026, 6, 21, 12, in: utc))
        #expect(abs(june.latitude - 23.44) < 0.1)
        #expect(abs(june.longitude) < 1)
        #expect(abs(SunPosition(at: date(2026, 12, 21, 12, in: utc)).latitude + 23.43) < 0.1)
        #expect(abs(SunPosition(at: date(2026, 3, 20, 12, in: utc)).latitude) < 0.5)
    }

    @Test func followsTheClockWestward() {
        // 18:00 UTC in November: over the Americas, ~4° extra from the equation of time.
        let sun = SunPosition(at: date(2026, 11, 10, 18, in: utc))
        #expect(abs(sun.longitude + 94) < 1)
    }

    @Test func dayAndNightSides() {
        let sun = SunPosition(at: date(2026, 11, 10, 18, in: utc))
        #expect(sun.height(latitude: 40.7, longitude: -74) > 0)
        #expect(sun.height(latitude: 31.2, longitude: 121.5) < 0)
        #expect(abs(sun.height(latitude: sun.terminator(longitude: 0), longitude: 0)) < 1e-9)
    }

    @Test func citiesHaveCoordinates() {
        #expect(WorldCity(timeZoneIdentifier: "America/Vancouver").coordinate?.latitude == 49.3)
        #expect(WorldCity(name: "Beijing", timeZoneIdentifier: "Asia/Shanghai").coordinate?.longitude == 121.5)
        #expect(WorldMapData.land.allSatisfy { $0.count == 120 })
    }
}
