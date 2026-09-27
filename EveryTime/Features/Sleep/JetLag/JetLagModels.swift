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
    struct Leg: Codable, Identifiable, Equatable {
        var id = UUID()
        var destination: WorldCity
        var departure: Date
        var arrival: Date
    }

    /// Legs flown back to back, planned as one shift toward the last destination.
    struct Stage: Equatable {
        let legs: ArraySlice<Leg>
        var destination: WorldCity { legs.last!.destination }
        var departure: Date { legs.first!.departure }
        var arrival: Date { legs.last!.arrival }
    }

    /// Shorter stopovers don't get their own adjustment; the plan keeps shifting toward the next stay.
    static let shortStopover: TimeInterval = 48 * 3600

    var id = UUID()
    var origin: WorldCity
    /// Never empty.
    var legs: [Leg]
    var preAdjustDays = 2
    var notifications = true

    init(id: UUID = UUID(), origin: WorldCity, legs: [Leg], preAdjustDays: Int = 2, notifications: Bool = true) {
        self.id = id
        self.origin = origin
        self.legs = legs
        self.preAdjustDays = preAdjustDays
        self.notifications = notifications
    }

    init(origin: WorldCity, destination: WorldCity, departure: Date, arrival: Date, preAdjustDays: Int = 2) {
        self.init(origin: origin, legs: [Leg(destination: destination, departure: departure, arrival: arrival)],
                  preAdjustDays: preAdjustDays)
    }

    var destination: WorldCity { legs.last!.destination }
    var departure: Date { legs.first!.departure }
    var arrival: Date { legs.last!.arrival }

    var cities: [WorldCity] { [origin] + legs.map(\.destination) }

    /// City each leg takes off from.
    func from(_ leg: Leg) -> WorldCity {
        legs.firstIndex(of: leg).flatMap { $0 > 0 ? legs[$0 - 1].destination : nil } ?? origin
    }

    var stages: [Stage] {
        var stages: [Stage] = [], start = 0
        for i in legs.indices where i + 1 == legs.count
            || legs[i + 1].departure.timeIntervalSince(legs[i].arrival) >= Self.shortStopover {
            stages.append(Stage(legs: legs[start...i]))
            start = i + 1
        }
        return stages
    }

    private enum CodingKeys: String, CodingKey {
        case id, origin, legs, preAdjustDays, notifications
        case destination, departure, arrival
    }

    /// Single-leg trips saved before `legs` existed decode as one leg.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        origin = try c.decode(WorldCity.self, forKey: .origin)
        preAdjustDays = try c.decodeIfPresent(Int.self, forKey: .preAdjustDays) ?? 2
        notifications = try c.decodeIfPresent(Bool.self, forKey: .notifications) ?? true
        if let legs = try c.decodeIfPresent([Leg].self, forKey: .legs), !legs.isEmpty {
            self.legs = legs
        } else {
            legs = [Leg(destination: try c.decode(WorldCity.self, forKey: .destination),
                        departure: try c.decode(Date.self, forKey: .departure),
                        arrival: try c.decode(Date.self, forKey: .arrival))]
        }
    }

    /// Also writes the old single-leg fields, so older app versions still read backups (as origin → final).
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(origin, forKey: .origin)
        try c.encode(legs, forKey: .legs)
        try c.encode(preAdjustDays, forKey: .preAdjustDays)
        try c.encode(notifications, forKey: .notifications)
        try c.encode(destination, forKey: .destination)
        try c.encode(departure, forKey: .departure)
        try c.encode(arrival, forKey: .arrival)
    }
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
    /// Where the traveller is that day: switches at each landing.
    let timeZone: TimeZone
    let index: Int
    let isTravelDay: Bool
    let isAdapted: Bool
    let actions: [PlanAction]
}

struct JetLagPlan: Equatable {
    /// Hours the body clock must move for the first stage; negative = advance (eastward).
    let shiftHours: Double
    let direction: ShiftDirection
    let days: [PlanDay]

    static let empty = JetLagPlan(shiftHours: 0, direction: .none, days: [])
}
