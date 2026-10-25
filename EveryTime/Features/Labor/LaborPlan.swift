import Foundation

/// The answers from setup. The go rule, its reasons and when to leave are derived from them (`plan`).
struct LaborSettings: Codable, Equatable {
    enum Transport: String, Codable, CaseIterable {
        case car, rideshare, pickup, walk

        var title: String {
            switch self {
            case .car: "Our car — someone else drives"
            case .rideshare: "Taxi or rideshare"
            case .pickup: "Someone picks us up"
            case .walk: "Walk — it's very close"
            }
        }

        var short: String {
            switch self {
            case .car: "by car"
            case .rideshare: "by taxi"
            case .pickup: "with a pick-up"
            case .walk: "on foot"
            }
        }

        /// Minutes before you're on the way: waiting for the ride.
        var wait: Int {
            switch self {
            case .car, .walk: 0
            case .rideshare, .pickup: 15
            }
        }
    }

    enum Condition: String, Codable, CaseIterable {
        case gbs, previousCesarean, multiples, breech, plannedCesarean, highBloodPressure, toldEarly

        var title: String {
            switch self {
            case .gbs: "Group B strep (GBS) positive"
            case .previousCesarean: "Previous C-section"
            case .multiples: "Twins or more"
            case .breech: "Baby is breech (bottom or feet first)"
            case .plannedCesarean: "Planned C-section"
            case .highBloodPressure: "High blood pressure / preeclampsia"
            case .toldEarly: "Care team said: come in early"
            }
        }

        var short: String {
            switch self {
            case .gbs: "GBS positive"
            case .previousCesarean: "previous C-section"
            case .multiples: "twins"
            case .breech: "breech baby"
            case .plannedCesarean: "planned C-section"
            case .highBloodPressure: "high blood pressure"
            case .toldEarly: "care team's advice"
            }
        }
    }

    var firstBaby = true
    var fastLastLabor = false
    var dueDate: Date?
    var hospital = ""
    var phone = ""
    /// Door to door, 0 = not set.
    var travelMinutes = 0
    var transport = Transport.car
    var conditions: Set<Condition> = []
    /// The rule your care team gave you; replaces the derived one.
    var careTeamRule: LaborRule?
    var emergency = StoreRegion.current == .cn ? "120" : "911"
    var setupDone = false
    /// Skipped from the main screen; a "Finish setup" row stays until it's done.
    var setupSkipped = false

    init() {}

    var rule: LaborRule { plan.rule }

    /// Fields added later decode as their defaults; a pre-setup custom `rule` becomes the care team's.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = LaborSettings()
        firstBaby = try c.decodeIfPresent(Bool.self, forKey: .firstBaby) ?? d.firstBaby
        fastLastLabor = try c.decodeIfPresent(Bool.self, forKey: .fastLastLabor) ?? d.fastLastLabor
        dueDate = try c.decodeIfPresent(Date.self, forKey: .dueDate)
        hospital = try c.decodeIfPresent(String.self, forKey: .hospital) ?? d.hospital
        phone = try c.decodeIfPresent(String.self, forKey: .phone) ?? d.phone
        travelMinutes = try c.decodeIfPresent(Int.self, forKey: .travelMinutes) ?? d.travelMinutes
        transport = (try? c.decodeIfPresent(Transport.self, forKey: .transport)) ?? d.transport
        conditions = Set((try? c.decodeIfPresent([String].self, forKey: .conditions))?.compactMap(Condition.init) ?? [])
        careTeamRule = try c.decodeIfPresent(LaborRule.self, forKey: .careTeamRule)
        if careTeamRule == nil, let old = try c.decodeIfPresent(LaborRule.self, forKey: .rule), old != .fiveOneOne {
            careTeamRule = old
        }
        emergency = try c.decodeIfPresent(String.self, forKey: .emergency) ?? d.emergency
        setupDone = try c.decodeIfPresent(Bool.self, forKey: .setupDone) ?? d.setupDone
        setupSkipped = try c.decodeIfPresent(Bool.self, forKey: .setupSkipped) ?? d.setupSkipped
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(firstBaby, forKey: .firstBaby)
        try c.encode(fastLastLabor, forKey: .fastLastLabor)
        try c.encodeIfPresent(dueDate, forKey: .dueDate)
        try c.encode(hospital, forKey: .hospital)
        try c.encode(phone, forKey: .phone)
        try c.encode(travelMinutes, forKey: .travelMinutes)
        try c.encode(transport, forKey: .transport)
        try c.encode(conditions.map(\.rawValue).sorted(), forKey: .conditions)
        try c.encodeIfPresent(careTeamRule, forKey: .careTeamRule)
        try c.encode(emergency, forKey: .emergency)
        try c.encode(setupDone, forKey: .setupDone)
        try c.encode(setupSkipped, forKey: .setupSkipped)
    }

    private enum CodingKeys: String, CodingKey {
        case firstBaby, fastLastLabor, dueDate, hospital, phone, travelMinutes, transport, conditions, careTeamRule, emergency, setupDone, setupSkipped, rule
    }

    /// Completed weeks and days at `now`, from a 40-week due date; nil outside a pregnancy (a mistyped year).
    func gestation(at now: Date, calendar: Calendar = .current) -> (weeks: Int, days: Int, daysToDue: Int)? {
        guard let dueDate else { return nil }
        let toDue = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: dueDate)).day ?? 0
        let total = 280 - toDue
        guard (0...Self.maxGestationDays).contains(total) else { return nil }
        return (total / 7, total % 7, toDue)
    }

    /// 44 weeks: past this the date must be wrong.
    static let maxGestationDays = 44 * 7

    /// Due dates the pickers allow: from 4 weeks past to 40 weeks ahead.
    static func dueRange(now: Date = .now, calendar: Calendar = .current) -> ClosedRange<Date> {
        let from = calendar.date(byAdding: .day, value: 280 - maxGestationDays, to: now) ?? now
        let to = calendar.date(byAdding: .day, value: 280, to: now) ?? now
        return from...to
    }

    /// Weeks for a due date not saved yet.
    static func gestation(due: Date, now: Date = .now) -> (weeks: Int, days: Int, daysToDue: Int)? {
        var settings = LaborSettings()
        settings.dueDate = due
        return settings.gestation(at: now)
    }

    /// What the due-date pickers show before one is set.
    static var suggestedDueDate: Date { Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now }

    // MARK: Plan

    /// Waiting for the ride plus the trip.
    var leaveMinutes: Int { travelMinutes > 0 ? travelMinutes + transport.wait : 0 }

    /// Over this, go earlier (Quebec INSPQ: more than 30 min away → go at 10 min apart).
    static let farMinutes = 30

    struct Plan: Equatable {
        let rule: LaborRule
        /// Why this rule, in plain words.
        let reason: String
        /// Call when contractions turn regular or waters break, without waiting for the rule.
        let firstSign: [Condition]
    }

    var plan: Plan {
        let firstSign = Condition.allCases.filter { conditions.contains($0) }
        if let careTeamRule {
            return Plan(rule: careTeamRule, reason: "Your care team's rule.", firstSign: firstSign)
        }
        if fastLastLabor {
            return Plan(rule: .tenOneOne, reason: "Your last labor was fast, so go early.", firstSign: firstSign)
        }
        if leaveMinutes > Self.farMinutes {
            return Plan(rule: .tenOneOne, reason: "It takes \(leaveMinutes) min to get there, so go early.", firstSign: firstSign)
        }
        if !firstBaby {
            return Plan(rule: .laterBaby, reason: "Later babies usually come faster, so no need to wait a full hour.", firstSign: firstSign)
        }
        return Plan(rule: .fiveOneOne, reason: "The usual rule for a first baby.", firstSign: firstSign)
    }

    /// "Call the hospital when contractions are 5:00 apart … Leave right after: about 40 min by car."
    var planSentence: String {
        let plan = plan
        let r = plan.rule
        var text = "Call \(hospital.isEmpty ? "the hospital" : hospital) when contractions are \(LaborAnalysis.clock(r.interval)) apart or closer, "
            + "each \(LaborAnalysis.clock(r.length)) long, for \(LaborAnalysis.span(r.window)). \(plan.reason)"
        if !plan.firstSign.isEmpty {
            text += " Because of \(plan.firstSign.map(\.short).joined(separator: ", ")): call at the first sign of labor."
        }
        if conditions.contains(.gbs) { text += " GBS positive: antibiotics should start early in labor." }
        if leaveMinutes > 0 { text += " Getting there takes about \(leaveMinutes) min \(transport.short)." }
        return text
    }
}

extension LaborRule {
    static let tenOneOne = LaborRule(interval: 10 * 60, length: 60, window: 3600)
    /// INSPQ: later births, every 5 min or less — without the full hour. 20 min = 4 gaps, the fewest the app reads.
    static let laterBaby = LaborRule(interval: 5 * 60, length: 60, window: 20 * 60)
}
