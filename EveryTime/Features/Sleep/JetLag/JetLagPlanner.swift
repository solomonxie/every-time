import Foundation

/// Pure, offline plan builder. Rules: docs/design/jet-lag/DESIGN.md (Model table).
enum JetLagPlanner {
    static let maxDays = 14
    static let napLength: TimeInterval = 25 * 60
    static let minWindow: TimeInterval = 15 * 60
    static let minSleep: TimeInterval = 60 * 60

    static func plan(profile: JetLagProfile, trip: Trip, now: Date = .now) -> JetLagPlan {
        let origin = trip.origin.timeZone
        guard !trip.legs.isEmpty, isOrdered(trip.legs) else { return .empty }

        let clock = BodyClock(profile)
        let stages = trip.stages
        let targets = stages.enumerated().map { i, stage in
            Target(from: i == 0 ? .distantPast : stage.departure,
                   offset: Double(stage.destination.timeZone.secondsFromGMT(for: stage.arrival)) / 3600)
        }
        let preAdjustDays = max(0, trip.preAdjustDays)
        let stayDays = Int((stages.last!.departure.timeIntervalSince(trip.departure) / 86_400).rounded(.up))
        let dayLimit = maxDays + stayDays

        let firstDay = calendar(origin).date(byAdding: .day, value: -preAdjustDays,
                                              to: calendar(origin).startOfDay(for: trip.departure))!
        let (cycles, shifts) = clock.cycles(firstCBT: firstDay.addingTimeInterval(clock.cbtOffset),
                                            alignedTo: Double(origin.secondsFromGMT(for: trip.departure)) / 3600,
                                            targets: targets,
                                            count: dayLimit + preAdjustDays + 4)
        let shiftHours = shifts.first ?? 0
        let direction: ShiftDirection = shiftHours < 0 ? .advance : .delay
        guard cycles.contains(where: \.shifting) else {
            return JetLagPlan(shiftHours: shiftHours, direction: .none, days: [])
        }

        let actions = buildActions(cycles, profile: profile, trip: trip)
        let days = buildDays(from: firstDay, trip: trip, origin: origin, limit: dayLimit)

        let adaptedWake = cycles.first { !$0.shifting && $0.stage == stages.count - 1 }?.wake
        let endInstant = max(adaptedWake ?? .distantFuture, trip.arrival)
        let lastIndex = days.lastIndex { $0.from <= endInstant }
            .flatMap { endInstant < days[$0].end ? $0 : nil }
        let isAdapted = adaptedWake != nil && lastIndex != nil
        let kept = days.prefix((lastIndex ?? days.count - 1) + 1)

        let planDays = kept.enumerated().map { i, day in
            let upper = i + 1 < kept.count ? kept[i + 1].from : day.end
            let dayActions = actions
                .filter { $0.start >= day.from && $0.start < upper }
                .sorted { ($0.start, $0.kind.order) < ($1.start, $1.kind.order) }
            return PlanDay(start: day.start, timeZone: day.timeZone, index: i,
                           isTravelDay: trip.legs.contains { day.start < $0.arrival && day.end > $0.departure },
                           isAdapted: isAdapted && i == kept.count - 1,
                           actions: dayActions)
        }
        return JetLagPlan(shiftHours: shiftHours, direction: direction, days: planDays)
    }

    private static func isOrdered(_ legs: [Trip.Leg]) -> Bool {
        legs.allSatisfy { $0.arrival >= $0.departure }
            && zip(legs, legs.dropFirst()).allSatisfy { $1.departure >= $0.arrival }
    }

    // MARK: - Actions

    private static func buildActions(_ cycles: [Cycle], profile: JetLagProfile, trip: Trip) -> [PlanAction] {
        let flights = trip.legs.map { Span($0.departure, $0.arrival) }
        var actions = flights.map { PlanAction(kind: .flight, start: $0.start, end: $0.end) }

        var sleeps: [Span] = [], flightSleeps: [Span] = []
        for c in cycles {
            let s = Span(c.bed, c.wake)
            let onBoard = flights.compactMap { s.intersection($0) }
            if onBoard.isEmpty {
                sleeps.append(s)
            } else {
                flightSleeps += onBoard.filter { $0.duration >= 30 * 60 }
                sleeps += s.subtracting(flights).filter { $0.duration >= minSleep }
            }
        }
        sleeps.sort { $0.start < $1.start }
        actions += sleeps.map { PlanAction(kind: .sleep, start: $0.start, end: $0.end) }
        actions += flightSleeps.map { PlanAction(kind: .sleepIfYouCan, start: $0.start, end: $0.end) }

        var windows: [(ActionKind, Span)] = []
        for (k, c) in cycles.enumerated() where c.shifting {
            windows += lightWindows(c, advancing: c.advancing)
            if profile.caffeine, k + 1 < cycles.count {
                let bed = cycles[k + 1].bed
                let cutoff = bed.addingTimeInterval(-8 * 3600)
                windows.append((.caffeineOK, Span(c.wake, cutoff)))
                windows.append((.caffeineAvoid, Span(max(cutoff, c.wake), bed)))
            }
            if profile.melatonin, c.advancing {
                let t = c.cbt.addingTimeInterval(-9.5 * 3600)
                actions.append(PlanAction(kind: .melatonin, start: t, end: t))
            }
        }
        let asleep = sleeps + flightSleeps
        for (kind, window) in windows {
            for piece in window.subtracting(asleep) where piece.duration >= minWindow {
                actions.append(PlanAction(kind: kind, start: piece.start, end: piece.end))
            }
        }

        for (a, b) in zip(sleeps, sleeps.dropFirst()) {
            let gap = Span(a.end, b.start)
            let awake = gap.subtracting(flightSleeps)
            guard gap.duration > 18 * 3600, flights.contains(where: { gap.intersection($0) != nil }),
                  let slot = awake.last.flatMap({ $0.duration >= 4 * 3600 ? $0 : nil })
                    ?? awake.max(by: { $0.duration < $1.duration }),
                  slot.duration >= napLength else { continue }
            let start = slot.mid.addingTimeInterval(-napLength / 2)
            actions.append(PlanAction(kind: .nap, start: start, end: start.addingTimeInterval(napLength)))
        }
        return actions
    }

    /// Table windows are anchored to CBTmin; a group that falls into its own sleep slides
    /// to the nearest awake edge (after wake / before bed), keeping order and length.
    private static func lightWindows(_ c: Cycle, advancing: Bool) -> [(ActionKind, Span)] {
        func w(_ kind: ActionKind, _ from: Double, _ to: Double) -> (ActionKind, Span) {
            (kind, Span(c.cbt.addingTimeInterval(from * 3600), c.cbt.addingTimeInterval(to * 3600)))
        }
        let before = advancing
            ? [w(.avoidLight, -4, 0)]
            : [w(.someLight, -5, -3), w(.brightLight, -3, 0)]
        let after = advancing
            ? [w(.brightLight, 0, 3), w(.someLight, 3, 5)]
            : [w(.avoidLight, 0, 4)]
        let back = min(0, c.bed.timeIntervalSince(before.map(\.1.end).max()!))
        let forward = max(0, c.wake.timeIntervalSince(after.map(\.1.start).min()!))
        return before.map { ($0.0, $0.1.offset(back)) } + after.map { ($0.0, $0.1.offset(forward)) }
    }

    // MARK: - Days

    private struct Day {
        let start: Date, end: Date, timeZone: TimeZone
        /// Lower bound for assigning actions; later than `start` when the zone switch overlaps.
        let from: Date
    }

    private static func buildDays(from firstDay: Date, trip: Trip, origin: TimeZone, limit: Int) -> [Day] {
        var days: [Day] = []
        var tz = origin, landed = 0, start = firstDay
        while days.count < limit {
            var end = calendar(tz).date(byAdding: .day, value: 1, to: start)!
            var from = start
            let dayStart = start
            while landed < trip.legs.count, trip.legs[landed].arrival < end {
                let leg = trip.legs[landed]
                landed += 1
                tz = leg.destination.timeZone
                let local = calendar(tz).startOfDay(for: leg.arrival)
                from = max(local, dayStart)
                start = local
                end = calendar(tz).date(byAdding: .day, value: 1, to: local)!
            }
            days.append(Day(start: start, end: end, timeZone: tz, from: from))
            start = end
        }
        return days
    }

    // MARK: - Helpers

    fileprivate static func wrapped(_ hours: Double) -> Double {
        var h = hours.truncatingRemainder(dividingBy: 24)
        if h <= -12 { h += 24 }
        if h > 12 { h -= 24 }
        return h
    }

    private static func calendar(_ tz: TimeZone) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = tz
        return c
    }
}

private struct Cycle {
    let cbt: Date, bed: Date, wake: Date
    /// Still ≥ 0.5 h from the stage's destination clock; gets light/caffeine/melatonin.
    let shifting: Bool
    let advancing: Bool
    let stage: Int
}

/// Body clock aims at `offset` (hours from GMT) from `from` on.
private struct Target {
    let from: Date
    let offset: Double
}

private struct BodyClock {
    let advanceRate: Double, delayRate: Double
    /// Habitual CBTmin, seconds after local midnight (may be negative).
    let cbtOffset: TimeInterval
    /// Habitual wake − habitual CBTmin.
    let wakeAfterCBT: TimeInterval
    let sleepLength: TimeInterval

    init(_ p: JetLagProfile) {
        let late = p.chronotype == .late, older = p.age >= 60
        let ageFactor = older ? 0.8 : 1
        advanceRate = (p.melatonin ? 1.5 : 1) * (late ? 0.85 : 1) * ageFactor
        delayRate = 1.5 * (late ? 1.1 : 1) * ageFactor
        let chrono: Double = switch p.chronotype {
        case .early: -0.5
        case .intermediate: 0
        case .late: 0.5
        }
        wakeAfterCBT = ((older ? 2.5 : 3) - chrono) * 3600
        cbtOffset = TimeInterval(p.usualWake * 60) - wakeAfterCBT
        sleepLength = p.sleepHours * 3600
    }

    /// At each new target the shift and direction are re-picked from where the clock is then.
    func cycles(firstCBT: Date, alignedTo offset: Double, targets: [Target],
                count: Int) -> (cycles: [Cycle], shifts: [Double]) {
        var aligned = offset, cbt = firstCBT, stage = -1
        var remaining = 0.0, advancing = true
        var result: [Cycle] = [], shifts: [Double] = []
        for _ in 0..<count {
            if let next = targets.indices.last(where: { targets[$0].from <= cbt }), next != stage {
                stage = next
                let delta = JetLagPlanner.wrapped(aligned - targets[next].offset)
                let advanceHours = delta < 0 ? -delta : 24 - delta
                let delayHours = 24 - advanceHours
                advancing = advanceHours / advanceRate <= delayHours / delayRate
                remaining = advancing ? advanceHours : delayHours
                shifts.append(advancing ? -advanceHours : delayHours)
            }
            let wake = cbt.addingTimeInterval(wakeAfterCBT)
            let shifting = remaining >= 0.5
            result.append(Cycle(cbt: cbt, bed: wake.addingTimeInterval(-sleepLength), wake: wake,
                                shifting: shifting, advancing: advancing, stage: stage))
            let step = shifting ? min(advancing ? advanceRate : delayRate, remaining) : 0
            remaining -= step
            aligned += advancing ? step : -step
            cbt = cbt.addingTimeInterval((24 + (advancing ? -step : step)) * 3600)
        }
        return (result, shifts)
    }
}

private struct Span {
    let start: Date, end: Date
    init(_ start: Date, _ end: Date) { self.start = start; self.end = end }

    var duration: TimeInterval { end.timeIntervalSince(start) }
    var mid: Date { start.addingTimeInterval(duration / 2) }

    func offset(_ t: TimeInterval) -> Span { Span(start.addingTimeInterval(t), end.addingTimeInterval(t)) }

    func intersection(_ o: Span) -> Span? {
        let s = max(start, o.start), e = min(end, o.end)
        return s < e ? Span(s, e) : nil
    }

    func subtracting(_ others: [Span]) -> [Span] {
        var pieces = duration > 0 ? [self] : []
        for o in others {
            pieces = pieces.flatMap { p -> [Span] in
                guard p.intersection(o) != nil else { return [p] }
                return [Span(p.start, o.start), Span(o.end, p.end)].filter { $0.duration > 0 }
            }
        }
        return pieces
    }
}

private extension ActionKind {
    var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}
