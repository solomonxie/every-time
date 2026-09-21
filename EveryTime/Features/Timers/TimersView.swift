import SwiftUI

struct TimersView: View {
    private let pastSessions = [
        TimerSession(kind: .leetcode, startedAt: Date().addingTimeInterval(-86400), duration: 1620),
        TimerSession(kind: .leetcode, startedAt: Date().addingTimeInterval(-172800), duration: 2100),
    ]

    var body: some View {
        NavigationStack {
            List {
                NavigationLink("LeetCode Timer") {
                    LeetCodeHistoryView(sessions: pastSessions)
                }
                NavigationLink("Interview Timer") {
                    TimerRunningView(title: "Interview Timer")
                }
                NavigationLink("Reversal Timer") {
                    TimerRunningView(title: "Reversal Timer")
                }
                NavigationLink("Stopwatch") {
                    TimerRunningView(title: "Stopwatch")
                }
            }
            .navigationTitle("Timers")
        }
    }
}

struct LeetCodeHistoryView: View {
    let sessions: [TimerSession]

    var body: some View {
        List {
            Section {
                NavigationLink("Start New Session") {
                    TimerRunningView(title: "LeetCode Timer")
                }
            }
            Section("Past Sessions") {
                ForEach(sessions) { session in
                    HStack {
                        Text(session.startedAt, style: .date)
                        Spacer()
                        Text(formatted(session.duration))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("LeetCode Timer")
    }

    private func formatted(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct TimerRunningView: View {
    let title: String

    var body: some View {
        VStack(spacing: 16) {
            Text("00:00")
                .font(.system(size: 56, weight: .light, design: .monospaced))
            HStack(spacing: 24) {
                Button("Start") {}
                Button("Stop") {}
                Button("Reset") {}
            }
        }
        .navigationTitle(title)
    }
}

#Preview {
    TimersView()
}
