import SwiftUI

struct TimersView: View {
    var body: some View {
        NavigationStack {
            List(TimerKind.allCases) { kind in
                NavigationLink(kind.rawValue) {
                    TimerDetailView(kind: kind)
                }
            }
            .navigationTitle("Timers")
        }
    }
}

struct TimerDetailView: View {
    let kind: TimerKind

    var body: some View {
        VStack(spacing: 16) {
            Text("00:00")
                .font(.system(size: 56, weight: .light, design: .monospaced))
            if kind == .leetcode {
                Text("Persistent history coming soon")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(kind.rawValue)
    }
}

#Preview {
    TimersView()
}
