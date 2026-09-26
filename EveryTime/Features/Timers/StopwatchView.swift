import SwiftUI

@Observable
final class StopwatchModel {
    let clock = ElapsedClock()
    private(set) var laps: [TimeInterval] = []

    func lap() {
        laps.append(clock.elapsed() - laps.reduce(0, +))
    }

    func clearLaps() {
        laps = []
    }
}

struct StopwatchView: View {
    let model: StopwatchModel

    var body: some View {
        VStack(spacing: 24) {
            ClockTimeline(clock: model.clock, interval: 0.01) { elapsed in
                Text(TimeText.precise(elapsed))
                    .timerDigits()
            }
            .padding(.top, 40)
            controls
            List {
                ForEach(model.laps.indices.reversed(), id: \.self) { index in
                    HStack {
                        Text("Lap \(index + 1)")
                        Spacer()
                        Text(TimeText.precise(model.laps[index]))
                            .monospacedDigit()
                    }
                    .foregroundStyle(color(for: model.laps[index]))
                }
            }
            .listStyle(.plain)
        }
        .navigationTitle(TimerKind.stopwatch.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .bigClock {
            BigClockView(clock: model.clock, interval: 0.01, controls: controls) {
                BigClockLabel(text: TimeText.precise($0))
            }
        }
    }

    private var controls: TimerControls {
        TimerControls(clock: model.clock, stopTitle: "Stop", onLap: model.lap, onReset: model.clearLaps)
    }

    private func color(for lap: TimeInterval) -> Color {
        guard model.laps.count > 1 else { return .primary }
        if lap == model.laps.min() { return .green }
        if lap == model.laps.max() { return .red }
        return .primary
    }
}
