import Foundation

enum TimerKind: String, CaseIterable, Identifiable {
    case leetcode = "LeetCode"
    case interview = "Interview"
    case reversal = "Reversal"
    case stopwatch = "Stopwatch"

    var id: String { rawValue }
}

struct TimerSession: Identifiable {
    let id = UUID()
    let kind: TimerKind
    let startedAt: Date
    let duration: TimeInterval
}
