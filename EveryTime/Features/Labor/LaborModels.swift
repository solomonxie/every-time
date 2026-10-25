import Foundation

/// One contraction; `end == nil` while it's on.
struct Contraction: Identifiable, Codable, Hashable {
    enum Strength: Int, Codable, CaseIterable, Comparable {
        case mild = 1, moderate, strong
        var title: String {
            switch self {
            case .mild: "Mild"
            case .moderate: "Moderate"
            case .strong: "Strong"
            }
        }
        static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
    }

    var id = UUID()
    var start: Date
    var end: Date?
    var strength: Strength?

    var length: TimeInterval? { end.map { $0.timeIntervalSince(start) } }
}

/// Something besides a contraction worth the timeline: waters, bleeding, rest…
struct LaborEvent: Identifiable, Codable, Hashable {
    enum Kind: String, Codable, CaseIterable {
        case waters, bleeding, show, lessMovement, rested, note, stage, pushing

        var title: String {
            switch self {
            case .waters: "Waters broke"
            case .bleeding: "Bleeding"
            case .show: "Show"
            case .lessMovement: "Moving less"
            case .rested: "Rested"
            case .note: "Note"
            case .stage: "Stage"
            case .pushing: "Baby coming"
            }
        }

        var symbol: String {
            switch self {
            case .waters: "drop.fill"
            case .bleeding: "drop.triangle.fill"
            case .show: "circle.dotted"
            case .lessMovement: "figure.and.child.holdinghands"
            case .rested: "bed.double.fill"
            case .note: "note.text"
            case .stage: "flag.fill"
            case .pushing: "staroflife.fill"
            }
        }

        /// Raises a red flag while recent.
        var isWarning: Bool { [.waters, .bleeding, .lessMovement, .pushing].contains(self) }
    }

    enum Fluid: String, Codable, CaseIterable {
        case clear, pink, greenBrown, smelly, unsure
        var title: String {
            switch self {
            case .clear: "Clear"
            case .pink: "Pink"
            case .greenBrown: "Green or brown"
            case .smelly: "Smelly"
            case .unsure: "Not sure"
            }
        }
        var isUrgent: Bool { self == .greenBrown || self == .smelly }
    }

    var id = UUID()
    var kind: Kind
    var time: Date
    var fluid: Fluid?
    var text: String?
    var stage: LaborStage?

    var title: String {
        if let stage, kind == .stage { return stage.title }
        if let fluid, kind == .waters { return "\(kind.title) · \(fluid.title.lowercased())" }
        if let text, !text.isEmpty { return kind == .note ? text : "\(kind.title) · \(text)" }
        return kind.title
    }
}

/// Where in labor you are; picked by you, suggested by the timing.
enum LaborStage: String, Codable, CaseIterable, Comparable {
    case before, early, active, hospital, born

    var title: String {
        switch self {
        case .before: "Before labor"
        case .early: "Early labor"
        case .active: "Active labor"
        case .hospital: "At the hospital"
        case .born: "Baby is born"
        }
    }

    var short: String {
        switch self {
        case .before: "Before"
        case .early: "Early"
        case .active: "Active"
        case .hospital: "Hospital"
        case .born: "Born"
        }
    }

    var next: LaborStage? { Self.allCases.firstIndex(of: self).flatMap { $0 + 1 < Self.allCases.count ? Self.allCases[$0 + 1] : nil } }

    static func < (a: Self, b: Self) -> Bool { allCases.firstIndex(of: a)! < allCases.firstIndex(of: b)! }
}

/// When to call or go in: contractions at most `interval` apart, lasting `length`, for `window`.
struct LaborRule: Codable, Hashable {
    var interval: TimeInterval
    var length: TimeInterval
    var window: TimeInterval

    /// "5-1-1" for the classic shape, else "5 min · 1:00 · 20 m".
    var name: String {
        let parts = [interval / 60, length / 60, window / 3600]
        if parts.allSatisfy({ $0 == $0.rounded() }) { return parts.map { String(Int($0)) }.joined(separator: "-") }
        return "\(Int(interval / 60)) min · \(LaborAnalysis.clock(length)) · \(LaborAnalysis.span(window))"
    }

    static let fiveOneOne = LaborRule(interval: 5 * 60, length: 60, window: 3600)
}

/// "Not yet" on a stage suggestion; it stays hidden for a while.
struct StageDismissal: Codable, Equatable {
    var stage: LaborStage
    var at: Date
}

/// One labor: its plan answers and its timeline.
struct LaborProfile: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var created = Date.now
    var settings = LaborSettings()
    var contractions: [Contraction] = []
    var events: [LaborEvent] = []
    var prep: Set<PrepItem> = []
    var notYet: StageDismissal?

    /// Ticked by hand, or done by what's already in the plan.
    func isDone(_ item: PrepItem) -> Bool {
        prep.contains(item) || (item == .plan && settings.setupDone) || (item == .phone && !settings.phone.isEmpty)
    }

    /// A new labor keeps how you get to the hospital; the rest is answered again in setup.
    static func next(after previous: LaborProfile?, name: String) -> LaborProfile {
        var profile = LaborProfile(name: name)
        if let old = previous?.settings {
            profile.settings.hospital = old.hospital
            profile.settings.phone = old.phone
            profile.settings.emergency = old.emergency
            profile.settings.travelMinutes = old.travelMinutes
            profile.settings.transport = old.transport
            profile.settings.firstBaby = false
        }
        return profile
    }
}

extension LaborProfile {
    /// Fields added later decode as their defaults.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "My labor"
        created = try c.decodeIfPresent(Date.self, forKey: .created) ?? .now
        settings = try c.decodeIfPresent(LaborSettings.self, forKey: .settings) ?? LaborSettings()
        contractions = try c.decodeIfPresent([Contraction].self, forKey: .contractions) ?? []
        events = try c.decodeIfPresent([LaborEvent].self, forKey: .events) ?? []
        prep = Set((try? c.decodeIfPresent([String].self, forKey: .prep))?.compactMap(PrepItem.init) ?? [])
        notYet = try? c.decodeIfPresent(StageDismissal.self, forKey: .notYet)
    }
}

enum LaborStore {
    static let profilesKey = "timers.labor.profiles"
    static let currentKey = "timers.labor.current"
    /// Stands in until something is saved; a fixed id so edits to it land on the same profile.
    static let defaultID = UUID(uuidString: "6C0F9A4E-1B7D-4C2A-9E57-3A1F0D2B8C11")!

    static func current(in profiles: [LaborProfile], id: String) -> LaborProfile {
        profiles.first { $0.id.uuidString == id } ?? profiles.first ?? LaborProfile(id: defaultID, name: "My labor")
    }

    /// A new labor after `current`, added at the end.
    static func adding(after current: LaborProfile, to profiles: [LaborProfile]) -> (profiles: [LaborProfile], next: LaborProfile) {
        let base = profiles.isEmpty ? [current] : profiles
        let next = LaborProfile.next(after: current, name: "Labor \(base.count + 1), \(Date.now.formatted(.dateTime.year()))")
        return (base + [next], next)
    }

    /// Before profiles: one labor across three keys.
    static let oldKeys = (contractions: "timers.labor.contractions", events: "timers.labor.events", settings: "timers.labor.settings")

    /// Moves the single pre-profile labor into the first profile, once; a restored old backup moves again.
    static func migrate(_ defaults: UserDefaults = AppData.defaults) {
        let contractions: [Contraction] = defaults.decoded(oldKeys.contractions) ?? []
        let events: [LaborEvent] = defaults.decoded(oldKeys.events) ?? []
        let settings: LaborSettings? = defaults.decoded(oldKeys.settings)
        guard !contractions.isEmpty || !events.isEmpty || settings != nil else { return }
        var profiles: [LaborProfile] = defaults.decoded(profilesKey) ?? []
        let created = contractions.map(\.start).min() ?? .now
        profiles.insert(LaborProfile(name: "My labor", created: created, settings: settings ?? LaborSettings(),
                                     contractions: contractions, events: events), at: 0)
        defaults.encode(profiles, profilesKey)
        guard defaults.decoded(profilesKey) as [LaborProfile]? == profiles else { return }
        // Only keys that read cleanly; unreadable bytes stay for recovery.
        if defaults.data(forKey: oldKeys.contractions) == nil || !contractions.isEmpty { defaults.removeObject(forKey: oldKeys.contractions) }
        if defaults.data(forKey: oldKeys.events) == nil || !events.isEmpty { defaults.removeObject(forKey: oldKeys.events) }
        if settings != nil { defaults.removeObject(forKey: oldKeys.settings) }
    }
}
