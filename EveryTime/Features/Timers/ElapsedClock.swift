import Foundation
import Observation

/// Date-based elapsed time: survives backgrounding because nothing ticks.
@Observable
final class ElapsedClock {
    private(set) var startedAt: Date?
    private(set) var accumulated: TimeInterval = 0

    var isRunning: Bool { startedAt != nil }
    var hasTime: Bool { isRunning || accumulated > 0 }

    func elapsed(at now: Date = .now) -> TimeInterval {
        guard let startedAt else { return accumulated }
        return accumulated + max(0, now.timeIntervalSince(startedAt))
    }

    func start() {
        guard startedAt == nil else { return }
        startedAt = .now
    }

    func pause() {
        accumulated = elapsed()
        startedAt = nil
    }

    func reset() {
        startedAt = nil
        accumulated = 0
    }
}

enum TimeText {
    /// `mm:ss`, or `h:mm:ss` past an hour.
    static func clock(_ seconds: Int) -> String {
        let (h, m, s) = (seconds / 3600, seconds / 60 % 60, seconds % 60)
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }

    /// `mm:ss.cc`
    static func precise(_ interval: TimeInterval) -> String {
        let centis = Int(interval * 100)
        return clock(centis / 100) + String(format: ".%02d", centis % 100)
    }

    /// Remaining time rounded up, or `+mm:ss` once past zero.
    static func countdown(_ remaining: TimeInterval) -> String {
        remaining > 0 ? clock(Int(remaining.rounded(.up))) : "+" + clock(Int(-remaining))
    }
}
