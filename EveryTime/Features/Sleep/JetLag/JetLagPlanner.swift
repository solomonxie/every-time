import Foundation

/// Pure, offline plan builder. Rules: docs/design/jet-lag/DESIGN.md (Model table).
enum JetLagPlanner {
    static let maxDays = 14
    static let napLength: TimeInterval = 25 * 60
    static let minWindow: TimeInterval = 15 * 60
    static let minSleep: TimeInterval = 60 * 60

    static func plan(profile: JetLagProfile, trip: Trip, now: Date = .now) -> JetLagPlan {
        let origin = trip.origin.timeZone, destination = trip.destination.timeZone
        let delta = wrapped(Double(origin.secondsFromGMT(for: trip.departure)
                                   - destination.secondsFromGMT(for: trip.arrival)) / 3600)
        guard abs(delta) >= 0.5, trip.arrival >= trip.departure else {
            return JetLagPlan(shiftHours: delta, direction: .none, days: [])
        }

        let clock = BodyClock(profile)
        let advanceHours = delta < 0 ? -delta : 24 - delta
        let delayHours = 24 - advanceHours
        let advancing = advanceHours / clock.advanceRate <= delayHours / clock.delayRate
        let shiftHours = advancing ? -advanceHours : delayHours

        let firstDay = calendar(origin).date(byAdding: .day, value: -max(0, trip.preAdjustDays),
                                              to: calendar(origin).startOfDay(for: trip.departure))!
        let cycles = clock.cycles(firstCBT: firstDay.addingTimeInterval(clock.cbtOffset),
                                  shiftHours: shiftHours,
                                  count: maxDays + max(0, trip.preAdjustDays) + 4)
        let actions = buildActions(cycles, profile: profile, trip: trip, advancing: advancing)
        let days = buildDays(from: firstDay, trip: trip, origin: origin, destination: destination)

        let adaptedWake = cycles.first { !$0.shifting }?.wake
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
                           isTravelDay: day.start < trip.arrival && day.end > trip.departure,
                           isAdapted: isAdapted && i == kept.count - 1,
                           actions: dayActions)
        }
        return JetLagPlan(shiftHours: shiftHours, direction: advancing ? .advance : .delay, days: planDays)
    }

    // MARK: - Actions

    private static func buildActions(_ cycles: [Cycle], profile: JetLagProfile, trip: Trip,
                                     advancing: Bool) -> [PlanAction] {
        let flight = Span(trip.departure, trip.arrival)
        var actions = [PlanAction(kind: .flight, start: trip.departure, end: trip.arrival)]

        var sleeps: [Span] = [], flightSleeps: [Span] = []
        for c in cycles {
            let s = Span(c.bed, c.wake)
            if let onBoard = s.intersection(flight) {
                if onBoard.duration >= 30 * 60 { flightSleeps.append(onBoard) }
                sleeps += s.subtracting([flight]).filter { $0.duration >= minSleep }
            } else {
                sleeps.append(s)
            }
        }
        sleeps.sort { $0.start < $1.start }
        actions += sleeps.map { PlanAction(kind: .sleep, start: $0.start, end: $0.end) }
        actions += flightSleeps.map { PlanAction(kind: .sleepIfYouCan, start: $0.start, end: $0.end) }

        var windows: [(ActionKind, Span)] = []
        for (k, c) in cycles.enumerated() where c.shifting {
            windows += lightWindows(c, advancing: advancing)
            if profile.caffeine, k + 1 < cycles.count {
                let bed = cycles[k + 1].bed
                let cutoff = bed.addingTimeInterval(-8 * 3600)
                windows.append((.caffeineOK, Span(c.wake, cutoff)))
                windows.append((.caffeineAvoid, Span(max(cutoff, c.wake), bed)))
            }
            if profile.melatonin, advancing {
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
            guard gap.duration > 18 * 3600, gap.intersection(flight) != nil,
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

    private static func buildDays(from firstDay: Date, trip: Trip,
                                  origin: TimeZone, destination: TimeZone) -> [Day] {
        var days: [Day] = []
        var tz = origin, arrived = false, start = firstDay
        while days.count < maxDays {
            var end = calendar(tz).date(byAdding: .day, value: 1, to: start)!
            var from = start
            if !arrived, trip.arrival < end {
                arrived = true
                tz = destination
                let local = calendar(tz).startOfDay(for: trip.arrival)
                from = max(local, start)
                start = local
                end = calendar(tz).date(byAdding: .day, value: 1, to: local)!
            }
            days.append(Day(start: start, end: end, timeZone: tz, from: from))
            start = end
        }
        return days
    }

    // MARK: - Helpers

    private static func wrapped(_ hours: Double) -> Double {
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
    /// Still ≥ 0.5 h from the destination clock; gets light/caffeine/melatonin.
    let shifting: Bool
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

    func cycles(firstCBT: Date, shiftHours: Double, count: Int) -> [Cycle] {
        let rate = shiftHours < 0 ? advanceRate : delayRate
        var remaining = abs(shiftHours), cbt = firstCBT
        var result: [Cycle] = []
        for _ in 0..<count {
            let wake = cbt.addingTimeInterval(wakeAfterCBT)
            let shifting = remaining >= 0.5
            result.append(Cycle(cbt: cbt, bed: wake.addingTimeInterval(-sleepLength), wake: wake,
                                shifting: shifting))
            let step = shifting ? min(rate, remaining) : 0
            remaining -= step
            cbt = cbt.addingTimeInterval((24 + (shiftHours < 0 ? -step : step)) * 3600)
        }
        return result
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
