import SwiftUI

/// Flat list of every secondary time tool, one tap each. Owns timer state so timers survive navigation.
struct MoreView: View {
    @State private var stopwatch = StopwatchModel()
    @State private var interview = ElapsedClock()
    @State private var reversal = ElapsedClock()
    @State private var leetcode = LeetCodeModel()

    @Stored("timers.interviewMinutes") private var interviewMinutes = 45
    @Stored("timers.reversalMinutes") private var reversalMinutes = 10
    @Stored("timers.leetcodeHistory") private var history: [TimerSession] = []

    var body: some View {
        NavigationStack {
            List {
                Section("Timers") {
                    ForEach(TimerKind.allCases) { kind in
                        NavigationLink(value: kind) {
                            LabeledContent {
                                detail(for: kind).monospacedDigit()
                            } label: {
                                Label(kind.rawValue, systemImage: kind.symbol)
                            }
                        }
                    }
                }
                Section("Dates") {
                    NavigationLink { SinceView() } label: { Label("How long since…", systemImage: "clock.arrow.circlepath") }
                    NavigationLink { WaitingView() } label: { Label("Wait times", systemImage: "hourglass") }
                }
                Section("Developer") {
                    NavigationLink { UnixTimestampView() } label: { Label("Unix timestamp", systemImage: "number") }
                    NavigationLink { TimestampConverterView() } label: { Label("Timestamp converter", systemImage: "arrow.left.arrow.right") }
                    NavigationLink { CronParserView() } label: { Label("Cron parser", systemImage: "calendar.badge.clock") }
                }
                Section {
                    NavigationLink { SettingsView() } label: { Label("Settings", systemImage: "gear") }
                }
            }
            .navigationTitle("More")
            .navigationDestination(for: TimerKind.self) { kind in
                switch kind {
                case .stopwatch:
                    StopwatchView(model: stopwatch)
                case .interview:
                    CountdownView(kind: .interview, clock: interview, minutes: $interviewMinutes)
                case .reversal:
                    CountdownView(kind: .reversal, clock: reversal, minutes: $reversalMinutes, step: 1)
                case .leetcode:
                    LeetCodeView(model: leetcode, history: $history)
                }
            }
        }
        .countdownAlarm(interview, minutes: interviewMinutes, allowsOvertime: false)
        .countdownAlarm(reversal, minutes: reversalMinutes, allowsOvertime: true)
    }

    @ViewBuilder
    private func detail(for kind: TimerKind) -> some View {
        switch kind {
        case .stopwatch:
            if stopwatch.clock.hasTime {
                ClockTimeline(clock: stopwatch.clock, interval: 1) { Text(TimeText.clock(Int($0))) }
            }
        case .interview:
            countdown(interview, minutes: interviewMinutes, allowsOvertime: false)
        case .reversal:
            countdown(reversal, minutes: reversalMinutes, allowsOvertime: true)
        case .leetcode:
            Text("^[\(history.count) session](inflect: true)")
        }
    }

    private func countdown(_ clock: ElapsedClock, minutes: Int, allowsOvertime: Bool) -> some View {
        ClockTimeline(clock: clock, interval: 1) { elapsed in
            let remaining = TimeInterval(minutes * 60) - elapsed
            Text(TimeText.countdown(allowsOvertime ? remaining : max(0, remaining)))
        }
    }
}

#Preview {
    MoreView()
}
