import SwiftUI

@Observable
final class LeetCodeModel {
    let clock = ElapsedClock()
    var problem = ""
    var difficulty = Difficulty.medium
}

struct LeetCodeView: View {
    @Bindable var model: LeetCodeModel
    @Binding var history: [TimerSession]

    var body: some View {
        List {
            Section {
                TextField("Problem", text: $model.problem, prompt: Text("1. Two Sum"))
                Picker("Difficulty", selection: $model.difficulty) {
                    ForEach(Difficulty.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                VStack(spacing: 16) {
                    ClockTimeline(clock: model.clock) { elapsed in
                        Text(TimeText.clock(Int(elapsed)))
                            .timerDigits(size: 56)
                    }
                    TimerControls(clock: model.clock)
                    Button("Finish & Save", action: save)
                        .buttonStyle(.borderedProminent)
                        .disabled(!model.clock.hasTime)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            Section {
                if history.isEmpty {
                    Text("No sessions yet — finish one to save it here")
                        .foregroundStyle(.secondary)
                }
                ForEach(history) { HistoryRow(session: $0) }
                    .onDelete { history.remove(atOffsets: $0) }
            } header: {
                HStack {
                    Text("History")
                    Spacer()
                    if !history.isEmpty {
                        Text("\(history.count) · avg \(TimeText.clock(averageSeconds))")
                    }
                }
            }
        }
        .navigationTitle(TimerKind.leetcode.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .bigClock {
            BigClockView(clock: model.clock, caption: model.problem, controls: TimerControls(clock: model.clock)) {
                BigClockLabel(text: TimeText.clock(Int($0)))
            }
        }
    }

    private var averageSeconds: Int {
        Int(history.map(\.duration).reduce(0, +) / Double(history.count))
    }

    private func save() {
        let name = model.problem.trimmingCharacters(in: .whitespaces)
        let session = TimerSession(
            problem: name.isEmpty ? "Untitled" : name,
            difficulty: model.difficulty,
            finishedAt: .now,
            duration: model.clock.elapsed()
        )
        history.insert(session, at: 0)
        model.clock.reset()
        model.problem = ""
    }
}

private struct HistoryRow: View {
    let session: TimerSession

    var body: some View {
        HStack {
            Text(session.problem)
                .lineLimit(1)
            Spacer()
            Text(session.difficulty.rawValue)
                .font(.caption)
                .foregroundStyle(session.difficulty.color)
            Text(TimeText.clock(Int(session.duration)))
                .monospacedDigit()
            Text(session.finishedAt, format: .dateTime.month(.abbreviated).day())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

extension Difficulty {
    var color: Color {
        switch self {
        case .easy: .green
        case .medium: .orange
        case .hard: .red
        }
    }
}
