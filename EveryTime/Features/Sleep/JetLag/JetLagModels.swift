import Foundation

enum Chronotype: String, Codable, CaseIterable, Identifiable {
    case early, intermediate, late
    var id: String { rawValue }
}

enum Sex: String, Codable, CaseIterable, Identifiable {
    case female, male, unspecified
    var id: String { rawValue }
}

struct JetLagProfile: Codable, Equatable {
    var age = 35
    var sex = Sex.unspecified
    var chronotype = Chronotype.intermediate
    /// Minutes after local midnight.
    var usualBedtime = 23 * 60
    var usualWake = 7 * 60
    var melatonin = false
    var caffeine = true
    var notifications = true

    var sleepHours: Double {
        Double((usualWake - usualBedtime + 24 * 60) % (24 * 60)) / 60
    }
}

struct Trip: Codable, Identifiable, Equatable {
    var id = UUID()
    var origin: WorldCity
    var destination: WorldCity
    var departure: Date
    var arrival: Date
    var preAdjustDays = 2
    var notifications = true
}

enum ShiftDirection: String, Codable {
    case advance, delay, none
}

enum ActionKind: String, Codable, CaseIterable {
    case brightLight, someLight, avoidLight
    case caffeineOK, caffeineAvoid
    case sleep, sleepIfYouCan, nap
    case melatonin
    case flight
}

struct PlanAction: Identifiable, Equatable {
    var id: String { "\(kind.rawValue)-\(start.timeIntervalSince1970)" }
    let kind: ActionKind
    let start: Date
    /// Equal to `start` for instant actions (melatonin).
    let end: Date
}

struct PlanDay: Identifiable, Equatable {
    var id: Date { start }
    /// Local midnight (in `timeZone`) that begins this day.
    let start: Date
    /// Where the traveller is that day: origin before departure, destination after.
    let timeZone: TimeZone
    let index: Int
    let isTravelDay: Bool
    let isAdapted: Bool
    let actions: [PlanAction]
}

struct JetLagPlan: Equatable {
    /// Hours the body clock must move; negative = advance (eastward).
    let shiftHours: Double
    let direction: ShiftDirection
    let days: [PlanDay]

    static let empty = JetLagPlan(shiftHours: 0, direction: .none, days: [])
}
