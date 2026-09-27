import Foundation
import Testing
@testable import EveryTime

struct JetLagPlannerTests {
    private let newYork = TimeZone(identifier: "America/New_York")!
    private let london = TimeZone(identifier: "Europe/London")!

    private func trip(_ from: String, _ to: String, departure: Date, arrival: Date) -> Trip {
        Trip(origin: WorldCity(timeZoneIdentifier: from), destination: WorldCity(timeZoneIdentifier: to),
             departure: departure, arrival: arrival)
    }

    /// 19:00 New York → 07:00 London next morning, both on summer time.
    private var eastward: Trip {
        trip("America/New_York", "Europe/London",
             departure: date(2026, 6, 10, 19, in: newYork), arrival: date(2026, 6, 11, 7, in: london))
    }

    private func plan(_ trip: Trip, _ edit: (inout JetLagProfile) -> Void = { _ in }) -> JetLagPlan {
        var profile = JetLagProfile()
        edit(&profile)
        return JetLagPlanner.plan(profile: profile, trip: trip)
    }

    @Test func eastwardAdvances() {
        let result = plan(eastward)
        #expect(result.direction == .advance)
        #expect(result.shiftHours == -5)
    }

    @Test func westwardDelays() {
        let back = trip("Europe/London", "America/New_York",
                        departure: date(2026, 6, 20, 11, in: london), arrival: date(2026, 6, 20, 13, in: newYork))
        let result = plan(back)
        #expect(result.direction == .delay)
        #expect(result.shiftHours == 5)
    }

    @Test func dateLineWrapsToShorterShift() {
        let tokyo = TimeZone(identifier: "Asia/Tokyo")!
        let hop = trip("Asia/Tokyo", "Pacific/Honolulu",
                       departure: date(2026, 6, 10, 21, in: tokyo), arrival: date(2026, 6, 10, 9, in: TimeZone(identifier: "Pacific/Honolulu")!))
        let result = plan(hop)
        #expect(result.direction == .advance)
        #expect(result.shiftHours == -5)
    }

    @Test func noPlanWithoutShiftOrWithArrivalBeforeDeparture() {
        let local = plan(trip("Asia/Shanghai", "Asia/Hong_Kong",
                              departure: date(2026, 6, 10, 9), arrival: date(2026, 6, 10, 12)))
        #expect(local.direction == .none && local.days.isEmpty)
        let backwards = plan(trip("America/New_York", "Europe/London",
                                  departure: date(2026, 6, 11, 9), arrival: date(2026, 6, 10, 9)))
        #expect(backwards.direction == .none && backwards.days.isEmpty)
    }

    @Test func daysStartBeforeDepartureAndSwitchZoneOnArrival() {
        let days = plan(eastward).days
        #expect(!days.isEmpty && days.count <= JetLagPlanner.maxDays)
        #expect(days.map(\.index) == Array(days.indices))
        #expect(days[0].start == date(2026, 6, 8, in: newYork))
        #expect(days[0].timeZone == newYork)
        for day in days {
            let local = gregorian(day.timeZone)
            #expect(local.startOfDay(for: day.start) == day.start)
            #expect(day.timeZone == (day.start < date(2026, 6, 11, in: london) ? newYork : london))
        }
        #expect(days.filter(\.isTravelDay).map(\.start) == [date(2026, 6, 10, in: newYork), date(2026, 6, 11, in: london)])
        #expect(days.filter(\.isAdapted).map(\.index) == [days.count - 1])
    }

    @Test func actionsAreSortedAndFlightAppearsOnce() {
        let days = plan(eastward).days
        let actions = days.flatMap(\.actions)
        #expect(actions.filter { $0.kind == .flight } == [PlanAction(kind: .flight, start: eastward.departure, end: eastward.arrival)])
        for day in days {
            #expect(day.actions.map(\.start) == day.actions.map(\.start).sorted())
        }
    }

    @Test func noBedSleepDuringFlight() {
        let actions = plan(eastward).days.flatMap(\.actions)
        let flight = eastward.departure..<eastward.arrival
        #expect(actions.filter { $0.kind == .sleep }.allSatisfy { !($0.start < flight.upperBound && $0.end > flight.lowerBound) })
        #expect(actions.filter { $0.kind == .sleepIfYouCan }.allSatisfy { flight.contains($0.start) && $0.end <= flight.upperBound })
    }

    @Test func lightWindowsAvoidSleep() {
        let actions = plan(eastward).days.flatMap(\.actions)
        let sleeps = actions.filter { $0.kind == .sleep || $0.kind == .sleepIfYouCan }
        let light = actions.filter { [.brightLight, .someLight, .avoidLight].contains($0.kind) }
        #expect(!light.isEmpty)
        for window in light {
            #expect(window.end.timeIntervalSince(window.start) >= JetLagPlanner.minWindow)
            #expect(sleeps.allSatisfy { !($0.start < window.end && $0.end > window.start) })
        }
    }

    @Test func profileTogglesMelatoninAndCaffeine() {
        let kinds = { (result: JetLagPlan) in Set(result.days.flatMap(\.actions).map(\.kind)) }
        #expect(!kinds(plan(eastward)).contains(.melatonin))
        #expect(kinds(plan(eastward)).contains(.caffeineOK))
        #expect(kinds(plan(eastward) { $0.melatonin = true }).contains(.melatonin))
        #expect(!kinds(plan(eastward) { $0.caffeine = false }).contains(.caffeineOK))
        #expect(!kinds(plan(eastward) { $0.caffeine = false }).contains(.caffeineAvoid))
    }

    @Test func melatoninSpeedsUpAdvance() {
        let without = plan(eastward).days.count
        let with = plan(eastward) { $0.melatonin = true }.days.count
        #expect(with < without)
    }

    @Test func noPreAdjustStartsOnDepartureDay() {
        var direct = eastward
        direct.preAdjustDays = 0
        #expect(plan(direct).days.first?.start == date(2026, 6, 10, in: newYork))
    }
}
