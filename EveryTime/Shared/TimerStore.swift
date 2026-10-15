import SwiftUI

/// Live timer models shared by every tab, so a pinned timer and More show the same run.
@Observable
final class TimerStore {
    static let interviewMinutesKey = "timers.interviewMinutes"
    static let rehearsalMinutesKey = "timers.rehearsalMinutes"
    static let leetcodeHistoryKey = "timers.leetcodeHistory"
    static let defaultInterviewMinutes = 45
    static let defaultRehearsalMinutes = 10

    /// Live clocks, saved on every change so a closed app resumes them; kept out of backups (`BackupSnapshot.deviceKeys`).
    static let liveKey = "timers.live"

    let stopwatch = StopwatchModel()
    let interview = ElapsedClock()
    let rehearsal = ElapsedClock()
    let leetcode = LeetCodeModel()
    @ObservationIgnored private let defaults: UserDefaults

    private struct Live: Codable {
        var stopwatch = ElapsedClock.State()
        var laps: [TimeInterval] = []
        var interview = ElapsedClock.State()
        var rehearsal = ElapsedClock.State()
        var leetcode = ElapsedClock.State()
        var problem = ""
        var difficulty = Difficulty.medium
    }

    /// The real store, so demo mode doesn't hide a running timer.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let live: Live = defaults.decoded(Self.liveKey) {
            stopwatch.clock.state = live.stopwatch
            stopwatch.laps = live.laps
            interview.state = live.interview
            rehearsal.state = live.rehearsal
            leetcode.clock.state = live.leetcode
            leetcode.problem = live.problem
            leetcode.difficulty = live.difficulty
        }
        for clock in [stopwatch.clock, interview, rehearsal, leetcode.clock] {
            clock.onChange = { [unowned self] in save() }
        }
    }

    private func save() {
        let live = Live(stopwatch: stopwatch.clock.state, laps: stopwatch.laps, interview: interview.state,
                        rehearsal: rehearsal.state, leetcode: leetcode.clock.state,
                        problem: leetcode.problem, difficulty: leetcode.difficulty)
        defaults.encode(live, Self.liveKey)
    }
}

extension View {
    /// Countdown alarms for the shared timers; attach once at the root so they fire on any tab.
    func timerAlarms(_ store: TimerStore) -> some View {
        modifier(TimerAlarms(store: store))
    }
}

private struct TimerAlarms: ViewModifier {
    let store: TimerStore
    @Stored(TimerStore.interviewMinutesKey) private var interviewMinutes = TimerStore.defaultInterviewMinutes
    @Stored(TimerStore.rehearsalMinutesKey) private var rehearsalMinutes = TimerStore.defaultRehearsalMinutes

    func body(content: Content) -> some View {
        content
            .countdownAlarm(store.interview, minutes: interviewMinutes, allowsOvertime: false)
            .countdownAlarm(store.rehearsal, minutes: rehearsalMinutes, allowsOvertime: true)
    }
}
