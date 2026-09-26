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

    @State private var saves = 0

    var body: some View {
        List {
            Section {
                timer
                    .listRowInsets(EdgeInsets(top: 8, leading: Theme.padding, bottom: 28, trailing: Theme.padding))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            Section {
                if history.isEmpty {
                    Text("No sessions yet — finish one to save it here")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .historyRow()
                }
                ForEach(history) { HistoryRow(session: $0).historyRow() }
                    .onDelete { history.remove(atOffsets: $0) }
            } header: {
                SectionLabel(title: "History") {
                    Spacer(minLength: 0)
                    if !history.isEmpty {
                        Text(stats).font(.label).monospacedDigit().foregroundStyle(.secondary)
                    }
                }
                .textCase(nil)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .animation(.snappy, value: history)
        .bottomBar {
            Button("Finish & Save", action: save)
                .buttonStyle(.primary)
                .disabled(!model.clock.hasTime)
                .opacity(model.clock.hasTime ? 1 : 0.4)
        }
        .sensoryFeedback(.success, trigger: saves)
        .navigationTitle(TimerKind.leetcode.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .bigClock {
            BigClockView(clock: model.clock, caption: model.problem, controls: TimerControls(clock: model.clock)) {
                BigClockLabel(text: TimeText.clock(Int($0)))
            }
        }
    }

    private var timer: some View {
        VStack(spacing: 20) {
            TextField("Problem", text: $model.problem, prompt: Text("1. Two Sum"))
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .multilineTextAlignment(.center)
                .submitLabel(.done)
                .padding(.top, 12)
            DifficultyPills(selection: $model.difficulty)
            VStack(spacing: 6) {
                ClockTimeline(clock: model.clock, interval: 0.25) { elapsed in
                    let text = TimeText.clock(Int(elapsed))
                    Text(text)
                        .timerDigits()
                        .contentTransition(.numericText())
                        .animation(.snappy, value: text)
                }
                TimerCaption(text: model.clock.isRunning ? "Solving" : model.clock.hasTime ? "Paused" : "Ready")
            }
            .padding(.vertical, 12)
            TimerControls(clock: model.clock)
        }
        .frame(maxWidth: .infinity)
    }

    private var stats: String {
        let durations = history.map(\.duration)
        let average = Int(durations.reduce(0, +) / Double(durations.count))
        let best = Int(durations.min() ?? 0)
        return "\(history.count) · avg \(TimeText.clock(average)) · best \(TimeText.clock(best))"
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
        saves += 1
    }
}

private struct DifficultyPills: View {
    @Binding var selection: Difficulty

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Difficulty.allCases) { difficulty in
                let isSelected = difficulty == selection
                Button(difficulty.rawValue) { selection = difficulty }
                    .font(.label)
                    .foregroundStyle(isSelected ? difficulty.color : .secondary)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 34)
                    .background(isSelected ? difficulty.color.opacity(0.15) : Theme.cardFill, in: Capsule())
                    .contentShape(Capsule())
                    .buttonStyle(.plain)
            }
        }
        .animation(.snappy, value: selection)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

private struct HistoryRow: View {
    let session: TimerSession

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(session.problem)
                    .font(.system(.body, design: .rounded))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Circle().fill(session.difficulty.color).frame(width: 6, height: 6)
                    Text(session.difficulty.rawValue)
                    Text("·")
                    Text(session.finishedAt, format: .dateTime.month(.abbreviated).day())
                }
                .font(.label)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Text(TimeText.clock(Int(session.duration)))
                .font(.clock(20, weight: .regular))
        }
    }
}

private extension View {
    func historyRow() -> some View {
        listRowInsets(EdgeInsets(top: 10, leading: Theme.padding, bottom: 10, trailing: Theme.padding))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

extension Difficulty {
    var color: Color {
        switch self {
        case .easy: Theme.Tone.good
        case .medium: Theme.Tone.warn
        case .hard: Theme.Tone.bad
        }
    }
}
