import SwiftUI

/// Live timer models shared by every tab, so a pinned timer and More show the same run.
@Observable
final class TimerStore {
    static let interviewMinutesKey = "timers.interviewMinutes"
    static let rehearsalMinutesKey = "timers.rehearsalMinutes"
    static let leetcodeHistoryKey = "timers.leetcodeHistory"
    static let defaultInterviewMinutes = 45
    static let defaultRehearsalMinutes = 10

    let stopwatch = StopwatchModel()
    let interview = ElapsedClock()
    let rehearsal = ElapsedClock()
    let leetcode = LeetCodeModel()
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
