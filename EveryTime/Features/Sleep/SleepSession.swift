import Foundation

/// Logged sleeps with only a short wake between them (snooze, toilet), taken as one sleep.
struct SleepSession: Identifiable, Equatable {
    static let maxGap: TimeInterval = 15 * 60

    /// Oldest first; never empty.
    let parts: [Nap]

    var id: UUID { parts[0].id }
    var start: Date { parts[0].start }
    var end: Date { parts[parts.count - 1].end }
    var inBed: TimeInterval { parts.reduce(0) { $0 + $1.duration } }
    var ups: Int { parts.count - 1 }
    var awake: TimeInterval { max(0, end.timeIntervalSince(start) - inBed) }
    var isNight: Bool { !Night.isNap(inBed) }
    /// Falling asleep once at the start, then quickly after each wake.
    var asleep: TimeInterval { max(0, inBed - SleepSuggestion.fallAsleepTime - Double(ups) * WakeCheck.fallBackAsleep) }
    /// The latest rating.
    var energy: Int? { parts.last { $0.energy != nil }?.energy }

    /// Newest first.
    static func group(_ naps: [Nap]) -> [SleepSession] {
        var chains: [[Nap]] = []
        for nap in naps.sorted(by: { $0.start < $1.start }) {
            if let last = chains.last, let end = last.map(\.end).max(), nap.start.timeIntervalSince(end) <= maxGap {
                chains[chains.count - 1].append(nap)
            } else {
                chains.append([nap])
            }
        }
        return chains.reversed().map(SleepSession.init)
    }
}
