import Foundation

/// Reads the current episode of contractions: stats, trend, go rule, pattern and red flags.
/// Thresholds and their sources: docs/design/labor/DESIGN.md, RESEARCH.md.
struct LaborAnalysis {
    /// A longer gap between starts begins a new episode.
    static let episodeGap: TimeInterval = 3 * 3600
    /// Shorter is a mis-tap: shown, never counted.
    static let minLength: TimeInterval = 10
    /// Longer is "forgot to stop": its start counts, its length doesn't.
    static let maxLength: TimeInterval = 180
    /// NHS: a contraction over 2 min needs a call.
    static let longLength: TimeInterval = 120
    static let hour: TimeInterval = 3600
    /// Coefficient of variation of intervals; the app's own cut-offs, no clinical standard exists.
    static let regularCV = 0.30
    static let irregularCV = 0.45
    static let minIntervals = 4
    static let minTracked: TimeInterval = 20 * 60
    /// How long flag events (waters, bleeding, less movement) stay up.
    static let flagSpan: TimeInterval = 24 * 3600

    struct Stats: Equatable {
        var count = 0
        var intervals: [TimeInterval] = []
        var lengths: [TimeInterval] = []
        var strengths: [Contraction.Strength] = []

        var medianInterval: TimeInterval? { LaborAnalysis.median(intervals) }
        var medianLength: TimeInterval? { LaborAnalysis.median(lengths) }
        var variation: Double? {
            guard intervals.count >= 2 else { return nil }
            let mean = intervals.reduce(0, +) / Double(intervals.count)
            guard mean > 0 else { return nil }
            let variance = intervals.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(intervals.count)
            return variance.squareRoot() / mean
        }
        func share(_ strength: Contraction.Strength) -> Double? {
            strengths.isEmpty ? nil : Double(strengths.filter { $0 == strength }.count) / Double(strengths.count)
        }
    }

    struct Condition: Equatable {
        /// "Apart", "Each lasts", "Timed for".
        let title: String
        /// "≤ 5:00"
        let goal: String
        let value: String
        let isMet: Bool
        /// Why it isn't met when the value alone doesn't say.
        var hint: String?
    }

    struct RuleCheck: Equatable {
        let rule: LaborRule
        let conditions: [Condition]
        var isMet: Bool { conditions.allSatisfy(\.isMet) }
    }

    enum Pattern: Equatable {
        case keepTiming(needed: Int)
        case braxtonHicksLike, earlyLike, activeLike, veryClose, unclear

        var title: String {
            switch self {
            case .keepTiming: "Keep timing"
            case .braxtonHicksLike: "Like Braxton Hicks"
            case .earlyLike: "Early labor-like"
            case .activeLike: "Active labor-like"
            case .veryClose: "Very close together"
            case .unclear: "Unclear — keep timing"
            }
        }
    }

    struct Reason: Equatable {
        enum Sign { case labor, practice, neutral }
        let text: String
        let sign: Sign
    }

    struct Flag: Equatable, Identifiable {
        let id: String
        let text: String
        /// Dial the emergency number, not the hospital.
        var isEmergency = false
    }

    struct Birth: Equatable {
        let time: Date
        let laborStart: Date?
        let contractions: Int
    }

    let now: Date
    let settings: LaborSettings
    /// Current episode, oldest first; empty when the last start is over `episodeGap` ago.
    let episode: [Contraction]
    let events: [LaborEvent]
    let calendar: Calendar
    private let allContractions: [Contraction]

    /// Start-to-start gap to the previous real contraction, per contraction.
    private(set) var intervals: [UUID: TimeInterval] = [:]
    private(set) var lastHour = Stats()
    private(set) var hourBefore = Stats()
    private(set) var ruleCheck = RuleCheck(rule: .fiveOneOne, conditions: [])
    private(set) var pattern: (pattern: Pattern, reasons: [Reason]) = (.unclear, [])
    private(set) var flags: [Flag] = []

    init(contractions: [Contraction], events: [LaborEvent], settings: LaborSettings, now: Date, calendar: Calendar = .current) {
        self.now = now
        self.settings = settings
        self.events = events.sorted { $0.time < $1.time }
        self.calendar = calendar
        allContractions = contractions
        let current = Self.episodes(contractions.filter { $0.start <= now }).first ?? []
        episode = current.last.map { now.timeIntervalSince($0.start) <= Self.episodeGap || $0.end == nil } == true ? current : []
        intervals = Self.intervals(episode)
        lastHour = stats(from: now.addingTimeInterval(-Self.hour), to: now)
        hourBefore = stats(from: now.addingTimeInterval(-2 * Self.hour), to: now.addingTimeInterval(-Self.hour))
        ruleCheck = makeRuleCheck()
        pattern = makePattern()
        flags = makeFlags()
    }

    init(profile: LaborProfile, now: Date, calendar: Calendar = .current) {
        self.init(contractions: profile.contractions, events: profile.events, settings: profile.settings, now: now, calendar: calendar)
    }

    // MARK: Episodes

    /// Newest episode first, each oldest first.
    static func episodes(_ contractions: [Contraction]) -> [[Contraction]] {
        var result: [[Contraction]] = []
        for contraction in contractions.sorted(by: { $0.start < $1.start }) {
            if let last = result.last?.last, contraction.start.timeIntervalSince(last.start) <= episodeGap {
                result[result.count - 1].append(contraction)
            } else {
                result.append([contraction])
            }
        }
        return result.reversed()
    }

    static func isMisTap(_ c: Contraction) -> Bool { c.length.map { $0 < minLength } ?? false }
    static func countsLength(_ c: Contraction) -> Bool { c.length.map { $0 >= minLength && $0 <= maxLength } ?? false }

    /// Start-to-start gap to the previous real contraction within one episode.
    static func intervals(_ episode: [Contraction]) -> [UUID: TimeInterval] {
        let real = episode.filter { !isMisTap($0) }
        return Dictionary(uniqueKeysWithValues: zip(real.dropFirst(), real).map { ($0.id, $0.start.timeIntervalSince($1.start)) })
    }

    /// The same across every episode, for the timeline.
    static func allIntervals(_ contractions: [Contraction]) -> [UUID: TimeInterval] {
        episodes(contractions).reduce(into: [:]) { $0.merge(intervals($1)) { a, _ in a } }
    }

    var open: Contraction? { episode.last.flatMap { $0.end == nil ? $0 : nil } }
    var last: Contraction? { episode.last { !Self.isMisTap($0) } }
    var tracked: TimeInterval { episode.first.map { now.timeIntervalSince($0.start) } ?? 0 }

    // MARK: Stats

    /// Contractions starting in (from, to].
    func stats(from: Date, to: Date) -> Stats {
        let intervals = intervals
        var stats = Stats()
        for c in episode where c.start > from && c.start <= to && !Self.isMisTap(c) {
            stats.count += 1
            if let interval = intervals[c.id] { stats.intervals.append(interval) }
            if Self.countsLength(c), let length = c.length { stats.lengths.append(length) }
            if let strength = c.strength { stats.strengths.append(strength) }
        }
        return stats
    }

    // MARK: Go rule

    private func makeRuleCheck() -> RuleCheck {
        let rule = settings.rule
        let window = stats(from: now.addingTimeInterval(-rule.window), to: now)
        let enough = window.intervals.count >= Self.minIntervals
        let few = enough ? nil : "Needs \(Self.minIntervals) gaps in the last \(Self.span(rule.window)) — \(window.intervals.count) so far."
        let median = window.medianInterval
        let near = window.intervals.isEmpty ? 0 : Double(window.intervals.filter { $0 <= rule.interval + 60 }.count) / Double(window.intervals.count)
        let length = window.medianLength
        let medianOK = (median ?? .infinity) <= rule.interval
        let uneven = enough && medianOK && near < 0.8 ? "Only \(Int((near * 100).rounded()))% of gaps are near the goal; 80% needed." : nil
        return RuleCheck(rule: rule, conditions: [
            Condition(title: "Apart", goal: "≤ \(Self.clock(rule.interval))", value: median.map(Self.clock) ?? "—",
                      isMet: enough && medianOK && near >= 0.8, hint: few ?? uneven),
            Condition(title: "Each lasts", goal: "≥ \(Self.clock(rule.length))", value: length.map(Self.clock) ?? "—",
                      isMet: enough && (length ?? 0) >= rule.length - 5, hint: few),
            Condition(title: "Timed for", goal: Self.span(rule.window), value: Self.span(min(tracked, rule.window)),
                      isMet: enough && tracked >= rule.window),
        ])
    }

    // MARK: Pattern

    var isPreterm: Bool { settings.gestation(at: now, calendar: calendar).map { $0.weeks < 37 } ?? false }

    private func makePattern() -> (pattern: Pattern, reasons: [Reason]) {
        let hour = lastHour
        guard hour.intervals.count >= Self.minIntervals, tracked >= Self.minTracked,
              let interval = hour.medianInterval, let cv = hour.variation else {
            let needed = hour.intervals.count >= Self.minIntervals ? 0 : max(1, Self.minIntervals + 1 - hour.count)
            return (.keepTiming(needed: needed), [])
        }
        var reasons: [Reason] = []
        let percent = Int((cv * 100).rounded())
        if cv <= Self.regularCV {
            reasons.append(Reason(text: "Regular (varies \(percent)%)", sign: .labor))
        } else if cv >= Self.irregularCV {
            reasons.append(Reason(text: "Irregular (varies \(percent)%)", sign: .practice))
        } else {
            reasons.append(Reason(text: "Somewhat regular (varies \(percent)%)", sign: .neutral))
        }

        let before = hourBefore
        if tracked >= 2 * Self.hour - 60, before.intervals.count >= 2, let earlier = before.medianInterval {
            if interval <= earlier - 60 {
                reasons.append(Reason(text: "Closer by \(Self.clock(earlier - interval)) than the hour before", sign: .labor))
            } else if interval >= earlier - 30 {
                reasons.append(Reason(text: "Not getting closer than the hour before", sign: .practice))
            }
            if let length = hour.medianLength, let earlierLength = before.medianLength, length >= earlierLength + 10 {
                reasons.append(Reason(text: "Longer by \(Int(length - earlierLength)) s", sign: .labor))
            }
        }

        if (hour.share(.strong) ?? 0) >= 0.5 {
            reasons.append(Reason(text: "Mostly strong", sign: .labor))
        } else if (hour.share(.mild) ?? 0) >= 0.7 {
            reasons.append(Reason(text: "Mostly mild", sign: .practice))
        }

        if let rest = restEffect { reasons.append(rest) }

        let labor = reasons.filter { $0.sign == .labor }.count
        let practice = reasons.filter { $0.sign == .practice }.count
        let length = hour.medianLength ?? 0
        let pattern: Pattern
        if practice >= 2 && labor == 0 {
            if isPreterm {
                reasons.append(Reason(text: "Before 37 weeks — don't assume practice contractions", sign: .neutral))
                pattern = .unclear
            } else {
                pattern = .braxtonHicksLike
            }
        } else if cv <= Self.regularCV {
            if interval <= 180 && length >= 60 { pattern = .veryClose }
            else if interval <= 300 && length >= 40 { pattern = .activeLike }
            else if interval > 300 { pattern = .earlyLike }
            else { pattern = .unclear }
        } else {
            pattern = .unclear
        }
        return (pattern, reasons)
    }

    /// Rate in the hour before the latest "Rested" vs since; needs 30 min after it.
    var restEffect: Reason? {
        guard let rested = events.last(where: { $0.kind == .rested && $0.time <= now }),
              let first = episode.first, rested.time > first.start else { return nil }
        let after = now.timeIntervalSince(rested.time)
        guard after >= 30 * 60 else { return nil }
        let before = stats(from: rested.time.addingTimeInterval(-Self.hour), to: rested.time).count
        let since = stats(from: rested.time, to: now).count
        let beforeRate = Double(before)
        let sinceRate = Double(since) * Self.hour / min(after, Self.hour)
        guard beforeRate >= 2 else { return nil }
        if sinceRate < beforeRate / 2 { return Reason(text: "Eased after rest", sign: .practice) }
        if sinceRate >= beforeRate * 0.8 { return Reason(text: "Kept going after rest", sign: .labor) }
        return nil
    }

    // MARK: Stage

    /// The latest stage picked; before labor until one is.
    var stage: LaborStage { events.last { $0.kind == .stage && $0.time <= now }?.stage ?? .before }
    var stageStart: Date? { events.last { $0.kind == .stage && $0.time <= now }?.time }

    /// The next stage when the timing says so: regular → early, go rule met → active. Never past active.
    var suggestedStage: LaborStage? {
        switch stage {
        case .before:
            if ruleCheck.isMet { return .active }
            switch pattern.pattern {
            case .earlyLike, .activeLike, .veryClose: return .early
            default: return nil
            }
        case .early:
            return ruleCheck.isMet ? .active : nil
        default:
            return nil
        }
    }

    /// Birth time and when labor began: the first early/active pick, else the first contraction before birth.
    var birth: Birth? {
        guard stage == .born, let time = stageStart else { return nil }
        let picked = events.last { $0.kind == .stage && $0.stage == .before && $0.time < time }?.time ?? .distantPast
        let start = events.first { $0.kind == .stage && $0.time > picked && $0.time < time && ($0.stage == .early || $0.stage == .active) }?.time
        let labor = Self.episodes(allContractions.filter { $0.start < time }).first ?? []
        let first = [start, labor.first?.start].compactMap { $0 }.min()
        return Birth(time: time, laborStart: first, contractions: labor.filter { !Self.isMisTap($0) }.count)
    }

    // MARK: Advice

    struct Advice: Equatable {
        enum Tone { case calm, ready, go, urgent }
        let headline: String
        let detail: String
        let tone: Tone
    }

    /// The one plain-words answer at the top of the screen.
    var advice: Advice {
        if !flags.isEmpty {
            return Advice(headline: "Worth a call to your care team.", detail: "See the note above.", tone: .urgent)
        }
        if episode.isEmpty {
            return Advice(headline: "Tap Start when a contraction begins.", detail: "Tap again when it ends. The app does the math.", tone: .calm)
        }
        let rule = settings.rule
        let leave = settings.leaveMinutes > 0 ? " Then leave — about \(settings.leaveMinutes) min \(settings.transport.short)." : ""
        if ruleCheck.isMet {
            return Advice(headline: "Time to call the hospital.",
                          detail: "\(Self.clock(rule.interval)) apart or closer, \(Self.clock(rule.length)) long, for \(Self.span(rule.window)) — all three met." + leave,
                          tone: .go)
        }
        if stage == .active {
            return Advice(headline: "Call the hospital and go.", detail: "You've moved to active labor. Keep timing on the way." + leave, tone: .go)
        }
        let read = pattern
        if isPreterm {
            return Advice(headline: "Call your care team.",
                          detail: "Before 37 weeks, any sign of labor is worth a call — don't wait for a pattern.", tone: .go)
        }
        let firstSign = settings.plan.firstSign
        if !firstSign.isEmpty, [.earlyLike, .activeLike, .veryClose].contains(read.pattern) {
            return Advice(headline: "Time to call the hospital.",
                          detail: "Contractions are regular. Your plan says call at the first sign (\(firstSign.map(\.short).joined(separator: ", ")))." + leave,
                          tone: .go)
        }
        switch read.pattern {
        case .keepTiming(let needed):
            let left = Self.minTracked - tracked
            let parts = (needed > 0 ? [Self.count(needed, "more contraction")] : []) + (left >= 60 ? [Self.span(left)] : [])
            return Advice(headline: "Keep timing.",
                          detail: parts.isEmpty ? "A little longer to tell what this is." : parts.joined(separator: " and ") + " to tell what this is.",
                          tone: .calm)
        case .braxtonHicksLike:
            return Advice(headline: "Probably practice contractions (Braxton Hicks).",
                          detail: "Not regular and not getting closer. Rest and drink water — real labor keeps going.", tone: .calm)
        case .earlyLike:
            return Advice(headline: "Probably early labor. Rest at home.",
                          detail: "Regular, about \(Self.clock(lastHour.medianInterval ?? 0)) apart. Call when all three goals are met.", tone: .ready)
        case .activeLike:
            return Advice(headline: "Getting close. Keep timing.",
                          detail: "Regular and close together. Call when all three goals are met.", tone: .ready)
        case .veryClose:
            return Advice(headline: "Very close together. Get ready to go.",
                          detail: "Under 3 minutes apart. Call when all three goals are met — or now if you're worried.", tone: .ready)
        case .unclear:
            return Advice(headline: "Not clear yet. Keep timing.",
                          detail: read.reasons.first?.text ?? "Keep tapping each one.", tone: .calm)
        }
    }

    // MARK: Red flags

    private func makeFlags() -> [Flag] {
        guard stage < .hospital else { return [] }
        var flags: [Flag] = []
        let recent = events.filter { $0.time <= now && now.timeIntervalSince($0.time) <= Self.flagSpan }
        if let pushing = recent.last(where: { $0.kind == .pushing }) {
            flags.append(Flag(id: "emergency", text: "Baby may be coming (since \(Self.time(pushing.time))). Best to stay put and get low; "
                              + "if birth seems close, \(settings.emergency) can talk you through it.", isEmergency: true))
        }
        if let waters = recent.last(where: { $0.kind == .waters }) {
            let at = "Waters broke at \(Self.time(waters.time))" + (waters.fluid.map { " (\($0.title.lowercased()))" } ?? "") + ". "
            let advice = settings.conditions.contains(.gbs) ? "With GBS, give your care team a call soon — antibiotics work best started early."
                : waters.fluid?.isUrgent == true ? "That colour is worth a call to your care team soon."
                : "Let your care team know; they'll say whether to come in."
            flags.append(Flag(id: "waters", text: at + advice))
        }
        if let bleeding = recent.last(where: { $0.kind == .bleeding }) {
            flags.append(Flag(id: "bleeding", text: "Bleeding noted at \(Self.time(bleeding.time)). Worth giving your care team a call."))
        }
        if let less = recent.last(where: { $0.kind == .lessMovement }) {
            flags.append(Flag(id: "movement", text: "Baby moving less since \(Self.time(less.time)). Give your care team a call — they'd rather hear from you, even at night."))
        }
        if let open, now.timeIntervalSince(open.start) > Self.longLength {
            flags.append(Flag(id: "long", text: "This one is past 2 minutes. If they keep running this long, check in with your care team."))
        } else if lastHour.lengths.contains(where: { $0 > Self.longLength }) {
            flags.append(Flag(id: "long", text: "One lasted over 2 minutes. If that keeps happening, check in with your care team."))
        }
        let tenMinutes = stats(from: now.addingTimeInterval(-600), to: now).count
        if tenMinutes >= 6 {
            flags.append(Flag(id: "often", text: "\(tenMinutes) contractions in 10 minutes — that's very close together. A good time to call your care team."))
        }
        if isPreterm, let weeks = settings.gestation(at: now, calendar: calendar)?.weeks, lastHour.count >= 4 {
            flags.append(Flag(id: "preterm", text: "\(lastHour.count) contractions this hour at \(weeks) weeks. Before 37 weeks it's worth a call to your care team."))
        }
        return flags
    }

    // MARK: Summary

    func summary() -> String {
        var lines = ["Labor — \(now.formatted(date: .abbreviated, time: .shortened))"]
        if let gestation = settings.gestation(at: now, calendar: calendar) {
            lines.append("Pregnancy: \(gestation.weeks)+\(gestation.days) weeks")
        }
        if let first = episode.first {
            lines.append("Since \(Self.time(first.start)): " + Self.count(episode.filter { !Self.isMisTap($0) }.count, "contraction"))
            lines.append("Last hour: " + Self.describe(lastHour))
            if hourBefore.count > 0 { lines.append("Hour before: " + Self.describe(hourBefore)) }
            lines.append("\(settings.rule.name): \(ruleCheck.isMet ? "met" : "not met")")
            lines.append("Pattern by timing: \(pattern.pattern.title)" + (pattern.reasons.isEmpty ? "" : " (\(pattern.reasons.map(\.text).joined(separator: ", ")))"))
        }
        if let birth {
            lines.append("Born \(Self.time(birth.time))" + (birth.laborStart.map { " after \(Self.span(birth.time.timeIntervalSince($0))) of labor" } ?? ""))
        }
        let since = (episode.first?.start ?? now).addingTimeInterval(-Self.flagSpan)
        for event in events where event.time >= since && event.time <= now {
            lines.append("\(Self.time(event.time)) \(event.title)")
        }
        lines.append("Timed with Every Time — by timing only, not a medical exam.")
        return lines.joined(separator: "\n")
    }

    private static func describe(_ stats: Stats) -> String {
        var parts = [count(stats.count, "contraction")]
        if let interval = stats.medianInterval { parts.append("every \(clock(interval))") }
        if let length = stats.medianLength { parts.append("lasting \(clock(length))") }
        if let strongest = stats.strengths.max() { parts.append("up to \(strongest.title.lowercased())") }
        return parts.joined(separator: ", ")
    }

    // MARK: Helpers

    static func median(_ values: [TimeInterval]) -> TimeInterval? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }

    /// `m:ss`
    static func clock(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded())
        return s >= 3600 ? span(seconds) : String(format: "%d:%02d", s / 60, s % 60)
    }

    /// `1 h 12 m`, `38 m`
    static func span(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        return m >= 60 ? (m % 60 == 0 ? "\(m / 60) h" : "\(m / 60) h \(m % 60) m") : "\(m) m"
    }

    static func time(_ date: Date) -> String { date.formatted(date: .omitted, time: .shortened) }

    /// "1 contraction", "3 contractions".
    static func count(_ n: Int, _ noun: String) -> String {
        String(AttributedString(localized: "^[\(n) \(noun)](inflect: true)").characters)
    }
}
