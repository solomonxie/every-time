import Foundation

/// "What if I sleep now?" — what sleeping at `start` means for the day's plan: nap, early night or cycle wake times.
struct SleepNow {
    enum Zone { case beforeWindow, napWindow, evening, bedtime, lateNight }

    struct Option: Identifiable, Equatable {
        enum Kind: Equatable {
            case nap(minutes: Int)
            /// Stay up and go to bed earlier than planned.
            case bedAt(Date)
            /// Sleep for the night now, well before bed: likely to wake in the small hours.
            case splitNight(wakeFrom: Date, wakeTo: Date)
            case night(cycles: Int, wake: Date)
        }

        let kind: Kind
        let title: String
        let detail: String
        let time: Date
        let level: NapAdvice.Level
        var isRecommended = false

        var id: String {
            switch kind {
            case .nap(let minutes): "nap\(minutes)"
            case .bedAt: "bed"
            case .splitNight: "split"
            case .night(let cycles, _): "night\(cycles)"
            }
        }
    }

    struct Segment: Equatable {
        enum Kind { case awake, nap, sleep, restless, drift }
        let kind: Kind
        let start: Date
        let end: Date
    }

    static let offsets = [0, 15, 30, 60]
    /// Evening sleep this far before bed is likely to become the night's first cycles.
    private static let splitHours = 3.0
    private static let bedtimeLead: TimeInterval = 90 * 60
    private static let lateAfterBed: TimeInterval = 2 * 3600
    private static let cycle = SleepSuggestion.cycleLength
    private static let fallAsleep = SleepSuggestion.fallAsleepTime

    let advice: NapAdvice
    let start: Date
    let day: NapAdvice.Day
    let zone: Zone

    init(advice: NapAdvice, start: Date) {
        self.advice = advice
        self.start = start
        let day = advice.current(at: start)
        self.day = day
        let window = advice.window(on: day.wake)
        zone = switch start {
        case day.bed.addingTimeInterval(Self.lateAfterBed)...: .lateNight
        case day.bed.addingTimeInterval(-Self.bedtimeLead)...: .bedtime
        case ..<window.start: .beforeWindow
        case ...window.end: .napWindow
        default: .evening
        }
    }

    var window: DateInterval { advice.window(on: day.wake) }
    private var hoursToBed: Double { day.bed.timeIntervalSince(start) / 3600 }
    private var isFarFromBed: Bool { hoursToBed > Self.splitHours }

    // MARK: Options

    /// Daytime: sleeping now can only be a nap.
    var isDaytime: Bool { zone == .beforeWindow || zone == .napWindow }

    /// Every nap length, with the pick for now marked if any is worth taking.
    var napOptions: [Option] {
        let pick = napPick
        return naps.map { option in
            var option = option
            option.isRecommended = option.kind == .nap(minutes: pick ?? -1)
            return option
        }
    }

    /// Ways to sleep for the night from now; none during the day.
    var sleepOptions: [Option] {
        var options: [Option] = switch zone {
        case .beforeWindow, .napWindow: []
        case .evening: [bedEarlier, nightNow].compactMap { $0 }
        case .bedtime, .lateNight: nights
        }
        let pick = sleepPick(in: options)
        for i in options.indices { options[i].isRecommended = options[i].id == pick }
        return options
    }

    private var napPick: Int? {
        switch zone {
        case .beforeWindow: return NapAdvice.suggestedMinutes
        case .napWindow: return advice.suggestedMinutes(on: day.wake)
        case .evening:
            return [NapAdvice.suggestedMinutes, 10].first { minutes in
                naps.contains { $0.kind == .nap(minutes: minutes) && $0.level != .high }
            }
        case .bedtime: return nil
        case .lateNight: return nights.isEmpty ? NapAdvice.suggestedMinutes : nil
        }
    }

    private func sleepPick(in options: [Option]) -> String? {
        switch zone {
        case .beforeWindow, .napWindow: return nil
        case .evening: return options.first { $0.level != .high }?.id
        case .bedtime, .lateNight:
            let fits = options.filter { if case .night(_, let wake) = $0.kind { wake <= day.nextWake } else { false } }
            return (fits.first ?? options.last)?.id
        }
    }

    private var naps: [Option] {
        NapAdvice.lengths.map { minutes in
            let tonight = advice.tonight(start: start, minutes: minutes, bed: day.bed)
            return Option(kind: .nap(minutes: minutes), title: "Nap \(minutes) min",
                          detail: "\(NapAdvice.tonightText(tonight)) · \(NapAdvice.wakeText(minutes: minutes))",
                          time: start.addingTimeInterval(Double(minutes) * 60),
                          level: max(tonight, NapAdvice.grogginess(minutes: minutes)))
        }
    }

    /// The earliest 5–6-cycle bedtime for the planned wake, if it's before the planned bed.
    private var bedEarlier: Option? {
        let earliest = start.addingTimeInterval(30 * 60)
        guard let bed = SleepSuggestion.bedtimes(wakingAt: day.nextWake)
            .first(where: { $0.isRecommended && $0.time >= earliest && $0.time < day.bed.addingTimeInterval(-20 * 60) })
        else { return nil }
        return Option(kind: .bedAt(bed.time), title: "Stay up a little",
                      detail: "\(bed.cycles) cycles (\(NapAdvice.hours(bed.hours))) before your \(Self.clock(day.nextWake)) wake",
                      time: bed.time, level: .low)
    }

    private var nightNow: Option {
        let asleep = start.addingTimeInterval(Self.fallAsleep)
        if isFarFromBed {
            let from = asleep.addingTimeInterval(3 * Self.cycle), to = asleep.addingTimeInterval(4 * Self.cycle)
            return Option(kind: .splitNight(wakeFrom: from, wakeTo: to), title: "Sleep for the night now",
                          detail: "Hard to fall back asleep until ~\(Self.clock(to))",
                          time: from, level: .high)
        }
        let cycles = max(1, Int(day.nextWake.timeIntervalSince(asleep) / Self.cycle))
        let wake = asleep.addingTimeInterval(Double(cycles) * Self.cycle)
        return Option(kind: .night(cycles: cycles, wake: wake), title: "Early night now",
                      detail: "\(cycles) full cycles",
                      time: wake, level: cycles >= 5 ? .low : .some)
    }

    /// Whole-cycle wake times that land by the planned wake (or a little after).
    private var nights: [Option] {
        let asleep = start.addingTimeInterval(Self.fallAsleep)
        let latest = day.nextWake.addingTimeInterval(30 * 60)
        return (1...6).reversed().compactMap { cycles in
            let wake = asleep.addingTimeInterval(Double(cycles) * Self.cycle)
            guard wake <= latest, cycles >= 3 || zone == .lateNight else { return nil }
            let late = wake > day.nextWake
            return Option(kind: .night(cycles: cycles, wake: wake), title: "Sleep \(NapAdvice.hours(Double(cycles) * 1.5))",
                          detail: "\(cycles) full cycle\(cycles == 1 ? "" : "s")"
                              + (late ? " · after your \(Self.clock(day.nextWake)) wake" : ""),
                          time: wake, level: cycles >= 5 ? .low : cycles >= 3 ? .some : .high)
        }
    }

    // MARK: Verdicts

    typealias Verdict = (headline: String, reason: String)

    /// A few words on sleeping for the night now, then why.
    var sleepVerdict: Verdict {
        switch zone {
        case .beforeWindow, .napWindow:
            return ("Too early for bed", "Sleeping now would be a nap.")
        case .evening:
            if case .splitNight(let from, _)? = sleepOptions.first(where: { $0.id == "split" })?.kind {
                return ("Risk of a split night",
                        "Sleep for the night now and you'll likely wake around \(Self.clock(from)), then struggle to fall back asleep.")
            }
            if case .bedAt(let bed)? = sleepOptions.first(where: { $0.id == "bed" })?.kind {
                return ("Close to bedtime", "Stay up until \(Self.clock(bed)), or make it an early night.")
            }
            return ("Close to bedtime", "An early night works.")
        case .bedtime:
            return ("Bedtime", "Asleep by ~\(Self.clock(start.addingTimeInterval(Self.fallAsleep))).")
        case .lateNight:
            return sleepOptions.isEmpty
                ? ("Past bedtime", "Under a cycle left before \(Self.clock(day.nextWake)).")
                : ("Past bedtime", "Wake times that still fit before \(Self.clock(day.nextWake)).")
        }
    }

    /// A few words on napping now, then why.
    var napVerdict: Verdict {
        let pick = napPick
        switch zone {
        case .beforeWindow:
            return ("Early for a nap", "If you can't wait, keep it to \(NapAdvice.suggestedMinutes) min.")
        case .napWindow:
            let minutes = pick ?? NapAdvice.suggestedMinutes
            return ("Good time for a nap",
                    minutes >= NapAdvice.longMinutes ? "A full \(minutes)-min cycle banks sleep before a late night."
                        : "\(minutes) min refreshes without grogginess.")
        case .evening:
            guard let pick else { return ("Too late for a nap", "It would push back tonight's sleep. An early night is better.") }
            return ("Late for a nap", "Keep it to \(pick) min so you still fall asleep on time.")
        case .bedtime:
            return ("Bedtime, not nap time", "A nap now eats into tonight's sleep.")
        case .lateNight:
            return pick == nil
                ? ("Past bedtime", "Go to bed instead; a nap now cuts into the night.")
                : ("Short on time", "Under a cycle left — a \(NapAdvice.suggestedMinutes)-min nap beats nothing.")
        }
    }

    var tip: String? {
        zone == .lateNight
            ? "Can't fall asleep after ~20 minutes? Get up in dim light, no screens, and go back when sleepy."
            : nil
    }

    // MARK: Timeline

    /// From `start` to the planned wake, what the option does to the night.
    func segments(for option: Option) -> [Segment] {
        let end = max(day.nextWake, option.time)
        let asleep = start.addingTimeInterval(Self.fallAsleep)
        switch option.kind {
        case .nap(let minutes):
            let napEnd = start.addingTimeInterval(Double(minutes) * 60)
            let drift: TimeInterval = switch advice.tonight(start: start, minutes: minutes, bed: day.bed) {
            case .low: 0
            case .some: 30 * 60
            case .high: 90 * 60
            }
            let bed = max(day.bed, napEnd)
            return Self.clean([
                Segment(kind: .nap, start: start, end: napEnd),
                Segment(kind: .awake, start: napEnd, end: bed),
                Segment(kind: .drift, start: bed, end: bed.addingTimeInterval(drift)),
                Segment(kind: .sleep, start: bed.addingTimeInterval(drift), end: end),
            ])
        case .bedAt(let bed):
            return Self.clean([
                Segment(kind: .awake, start: start, end: bed),
                Segment(kind: .sleep, start: bed.addingTimeInterval(Self.fallAsleep), end: end),
            ])
        case .splitNight(let from, let to):
            let backAsleep = max(to, from.addingTimeInterval(2.5 * 3600))
            return Self.clean([
                Segment(kind: .sleep, start: asleep, end: from),
                Segment(kind: .restless, start: from, end: backAsleep),
                Segment(kind: .sleep, start: backAsleep, end: end),
            ])
        case .night(_, let wake):
            return Self.clean([
                Segment(kind: .sleep, start: asleep, end: wake),
                Segment(kind: .awake, start: wake, end: end),
            ])
        }
    }

    private static func clean(_ segments: [Segment]) -> [Segment] {
        segments.filter { $0.end > $0.start }
    }

    static func clock(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}
