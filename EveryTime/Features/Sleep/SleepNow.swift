import Foundation

/// "What if I sleep now?" — every sensible wake time from `start`, with the pick for right now marked.
struct SleepNow {
    enum Zone { case beforeWindow, napWindow, evening, bedtime, lateNight }

    struct Option: Identifiable, Equatable {
        enum Kind: Equatable {
            case nap(minutes: Int)
            /// Sleep for the night now, well before bed: likely to wake in the small hours.
            case splitNight(wakeFrom: Date, wakeTo: Date)
            case night(cycles: Int, wake: Date)
        }

        let kind: Kind
        let title: String
        let detail: String
        /// When the alarm rings.
        let time: Date
        let level: NapAdvice.Level
        var isRecommended = false
        /// Past the usual wake: sleeping in.
        var isLate = false

        var id: String {
            switch kind {
            case .nap(let minutes): "nap\(minutes)"
            case .splitNight: "split"
            case .night(let cycles, _): "night\(cycles)"
            }
        }

        var isNap: Bool { if case .nap = kind { true } else { false } }

        /// Minutes to sleep from `now` to be up at `time`.
        func sleepMinutes(from now: Date) -> Int {
            switch kind {
            case .nap(let minutes): minutes
            case .night, .splitNight: max(1, Int((time.timeIntervalSince(now) / 60).rounded()))
            }
        }

        /// The short line under the chip.
        var caption: String {
            switch kind {
            case .nap(let minutes):
                if isRecommended { return "\(minutes) · best" }
                if minutes >= NapAdvice.longMinutes { return "\(minutes) · full cycle" }
                switch NapAdvice.grogginess(minutes: minutes) {
                case .low: return "\(minutes) min"
                case .some: return minutes >= NapAdvice.longMinutes ? "\(minutes) · full cycle" : "\(minutes) · groggy"
                case .high: return "\(minutes) · groggy"
                }
            case .splitNight: return "split night"
            case .night(let cycles, _):
                return isRecommended ? "\(cycles) · best" : isLate ? "\(cycles) · sleep in" : "\(cycles) \(cycles == 1 ? "cycle" : "cycles")"
            }
        }
    }

    /// Evening sleep this far before bed is likely to become the night's first cycles.
    private static let splitHours = 3.0
    private static let bedtimeLead: TimeInterval = 90 * 60
    private static let lateAfterBed: TimeInterval = 2 * 3600
    private static var cycle: TimeInterval { SleepSuggestion.cycleLength }
    private static var fallAsleep: TimeInterval { SleepSuggestion.fallAsleepTime }

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

    /// Wake chips for now, earliest first: by day every nap length; from evening on, whole-cycle wakes plus a short nap.
    var options: [Option] {
        let all: [Option]
        switch zone {
        case .beforeWindow, .napWindow:
            all = napOptions
        case .evening, .bedtime, .lateNight:
            let sleep = sleepOptions
            let naps = napOptions.filter { $0.level != .high || zone == .lateNight }
                .filter { if case .nap(let m) = $0.kind { m == NapAdvice.suggestedMinutes } else { false } }
                .map { nap in
                    var nap = nap
                    nap.isRecommended = nap.isRecommended && !sleep.contains(where: \.isRecommended)
                    return nap
                }
            all = sleep + naps
        }
        return all.sorted { $0.time < $1.time }
    }

    /// The one the button does.
    var pick: Option? { options.first(where: \.isRecommended) ?? options.first }

    /// The verdict that matters now: napping by day, sleeping for the night from evening.
    var verdict: Verdict { isDaytime ? napVerdict : sleepVerdict }

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
        case .evening: [nightNow]
        case .bedtime, .lateNight: nights
        }
        let pick = sleepPick(in: options)
        for i in options.indices { options[i].isRecommended = options[i].id == pick }
        return options
    }

    /// The earliest 5–6-cycle bedtime for the planned wake, if it's still ahead and before the usual bed.
    var bedBy: SleepSuggestion? {
        let earliest = start.addingTimeInterval(30 * 60)
        return SleepSuggestion.bedtimes(wakingAt: day.nextWake)
            .first { $0.isRecommended && $0.time >= earliest && $0.time < day.bed.addingTimeInterval(-20 * 60) }
    }

    private var napPick: Int? {
        switch zone {
        case .beforeWindow, .napWindow: return NapAdvice.suggestedMinutes
        case .evening:
            return [NapAdvice.suggestedMinutes, 10].first { minutes in
                naps.contains { $0.kind == .nap(minutes: minutes) && $0.level != .high }
            }
        case .bedtime: return nil
        case .lateNight: return sleepPick(in: nights) == nil ? NapAdvice.suggestedMinutes : nil
        }
    }

    private func sleepPick(in options: [Option]) -> String? {
        switch zone {
        case .beforeWindow, .napWindow: return nil
        case .evening: return options.first { $0.level != .high }?.id
        case .bedtime, .lateNight:
            let fits = options.filter { $0.time <= day.nextWake && $0.level != .high }
            // Under a cycle left: a nap is the answer, sleeping on is for sleeping in.
            return (fits.first ?? (zone == .bedtime ? options.last : nil))?.id
        }
    }

    private var naps: [Option] {
        // Past tonight's bed, a nap is judged against the next one.
        let bed = day.bed > start ? day.bed : advice.day(of: start).bed
        return NapAdvice.lengths.map { minutes in
            let tonight = advice.tonight(start: start, minutes: minutes, bed: bed)
            return Option(kind: .nap(minutes: minutes), title: "Nap \(minutes) min",
                          detail: "\(NapAdvice.tonightText(tonight)) · \(NapAdvice.wakeText(minutes: minutes))",
                          time: start.addingTimeInterval(Double(minutes) * 60),
                          level: max(tonight, NapAdvice.grogginess(minutes: minutes)))
        }
    }

    private var nightNow: Option {
        let asleep = start.addingTimeInterval(Self.fallAsleep)
        if isFarFromBed {
            let from = asleep.addingTimeInterval(3 * Self.cycle), to = asleep.addingTimeInterval(4 * Self.cycle)
            return Option(kind: .splitNight(wakeFrom: from, wakeTo: to), title: "Sleep now",
                          detail: "Hard to fall back asleep until ~\(Self.clock(to))",
                          time: from, level: .high)
        }
        let cycles = max(1, Int(day.nextWake.timeIntervalSince(asleep) / Self.cycle))
        let wake = asleep.addingTimeInterval(Double(cycles) * Self.cycle)
        return Option(kind: .night(cycles: cycles, wake: wake), title: "Sleep now",
                      detail: "\(cycles) full cycles",
                      time: wake, level: cycles >= 5 ? .low : .some)
    }

    /// Whole-cycle wake times from now, longest first; the ones past the planned wake are for sleeping in.
    private var nights: [Option] {
        let asleep = start.addingTimeInterval(Self.fallAsleep)
        return (1...6).reversed().compactMap { cycles in
            let wake = asleep.addingTimeInterval(Double(cycles) * Self.cycle)
            guard cycles >= 3 || zone == .lateNight else { return nil }
            let late = wake > day.nextWake.addingTimeInterval(15 * 60)
            return Option(kind: .night(cycles: cycles, wake: wake), title: "Sleep \(NapAdvice.hours(Double(cycles) * Self.cycle / 3600))",
                          detail: "\(cycles) full cycle\(cycles == 1 ? "" : "s")"
                              + (late ? " · after your \(Self.clock(day.nextWake)) wake" : ""),
                          time: wake, level: cycles >= 5 ? .low : cycles >= 3 ? .some : .high, isLate: late)
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
            if case .splitNight(let from, _) = nightNow.kind {
                return ("Risk of a split night",
                        "Sleep for the night now and you'll likely wake around \(Self.clock(from)), then struggle to fall back asleep.")
            }
            if let bed = bedBy {
                return ("Close to bedtime", "Bed by \(Self.clock(bed.time)) for \(bed.cycles) cycles before \(Self.clock(day.nextWake)).")
            }
            return ("Close to bedtime", "An early night works.")
        case .bedtime:
            return ("Bedtime", "Asleep by about \(Self.clock(start.addingTimeInterval(Self.fallAsleep))).")
        case .lateNight:
            return sleepOptions.contains(where: \.isRecommended)
                ? ("Past bedtime", "Wake times from now; past \(Self.clock(day.nextWake)) means sleeping in.")
                : ("Past bedtime", "Under a cycle left before \(Self.clock(day.nextWake)); sleeping on means sleeping in.")
        }
    }

    /// A few words on napping now, then why.
    var napVerdict: Verdict {
        let pick = napPick
        switch zone {
        case .beforeWindow:
            return ("Early for a nap", "If you can't wait, keep it to \(NapAdvice.suggestedMinutes) min.")
        case .napWindow:
            return ("Good time for a nap", "\(pick ?? NapAdvice.suggestedMinutes) min refreshes without grogginess.")
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

    static func clock(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}
