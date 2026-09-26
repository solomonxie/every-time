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
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                ClockTimeline(clock: model.clock, interval: 0.01) { elapsed in
                    Text(TimeText.precise(elapsed))
                        .timerDigits()
                }
                TimerCaption(text: caption)
            }
            .padding(.top, 56)
            .padding(.horizontal, Theme.padding)

            controls
                .padding(.horizontal, Theme.padding)
                .padding(.vertical, 36)

            laps
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .sensoryFeedback(.selection, trigger: model.laps.count) { _, new in new > 0 }
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

    private var caption: String {
        if model.clock.isRunning { return model.laps.isEmpty ? "Running" : "Lap \(model.laps.count + 1)" }
        return model.clock.hasTime ? "Stopped" : "Ready"
    }

    private var laps: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(model.laps.indices.reversed(), id: \.self) { index in
                    let lapTint = tint(for: model.laps[index])
                    HStack {
                        Text("Lap \(index + 1)")
                            .foregroundStyle(lapTint ?? .secondary)
                        Spacer()
                        Text(TimeText.precise(model.laps[index]))
                            .font(.clock(17, weight: .regular))
                            .foregroundStyle(lapTint ?? .primary)
                    }
                    .font(.system(.body, design: .rounded))
                    .padding(.vertical, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(.horizontal, Theme.padding)
            .animation(.snappy, value: model.laps.count)
        }
    }

    private func tint(for lap: TimeInterval) -> Color? {
        guard model.laps.count > 1 else { return nil }
        if lap == model.laps.min() { return Theme.Tone.good }
        if lap == model.laps.max() { return Theme.Tone.bad }
        return nil
    }
}
