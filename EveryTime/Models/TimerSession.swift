import Foundation

enum TimerKind: String, CaseIterable, Identifiable, Hashable {
    case stopwatch = "Stopwatch"
    case interview = "Interview"
    case reversal = "Reversal"
    case leetcode = "LeetCode"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .stopwatch: "stopwatch"
        case .interview: "mic"
        case .reversal: "arrow.counterclockwise"
        case .leetcode: "chevron.left.forwardslash.chevron.right"
        }
    }
}

enum Difficulty: String, Codable, CaseIterable, Identifiable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"

    var id: String { rawValue }
}

/// A finished LeetCode practice session.
struct TimerSession: Identifiable, Codable, Hashable {
    var id = UUID()
    var problem: String
    var difficulty: Difficulty
    var finishedAt: Date
    var duration: TimeInterval
}
