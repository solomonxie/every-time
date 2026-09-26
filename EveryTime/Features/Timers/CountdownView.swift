import SwiftUI

/// Interview (stops at zero) and Reversal (keeps counting as overtime).
struct CountdownView: View {
    let kind: TimerKind
    let clock: ElapsedClock
    @Binding var minutes: Int
    var step = 5

    private var allowsOvertime: Bool { kind == .reversal }
    private var duration: TimeInterval { TimeInterval(minutes * 60) }

    var body: some View {
        VStack(spacing: 32) {
            ClockTimeline(clock: clock) { elapsed in
                display(remaining: duration - elapsed)
            }
            .padding(.top, 40)
            controls
            Stepper(value: $minutes, in: step...180, step: step) {
                HStack {
                    Text("Duration")
                    Spacer()
                    Text("\(minutes) min")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(clock.isRunning)
            .padding(.horizontal)
            Spacer()
        }
        .navigationTitle(kind.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .bigClock {
            BigClockView(clock: clock, controls: controls) { elapsed in
                let remaining = duration - elapsed
                BigClockLabel(text: readout(remaining), note: note(remaining))
                    .foregroundStyle(tint(remaining))
            }
        }
    }

    private var controls: TimerControls {
        TimerControls(clock: clock, canStart: allowsOvertime || clock.elapsed() < duration)
    }

    private func readout(_ remaining: TimeInterval) -> String {
        remaining > 0 || allowsOvertime ? TimeText.countdown(remaining) : TimeText.clock(0)
    }

    private func note(_ remaining: TimeInterval) -> String? {
        guard remaining <= 0 else { return nil }
        return allowsOvertime ? "Overtime" : "Time's up"
    }

    private func tint(_ remaining: TimeInterval) -> Color {
        guard remaining <= 0 else { return .primary }
        return allowsOvertime ? .orange : .red
    }

    private func display(remaining: TimeInterval) -> some View {
        VStack(spacing: 12) {
            Text(readout(remaining))
                .timerDigits()
                .foregroundStyle(tint(remaining))
            if let note = note(remaining) {
                Text(note)
                    .foregroundStyle(tint(remaining))
            } else if !allowsOvertime {
                let fraction = remaining / duration
                ProgressView(value: fraction)
                    .padding(.horizontal, 40)
                Text(fraction, format: .percent.precision(.fractionLength(0)))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Haptic at zero; Interview also stops there. Attached above navigation so it fires from any screen.
private struct CountdownAlarm: ViewModifier {
    let clock: ElapsedClock
    let duration: TimeInterval
    let allowsOvertime: Bool

    @State private var alarms = 0

    func body(content: Content) -> some View {
        content
            .task(id: clock.isRunning) { await waitForZero() }
            .sensoryFeedback(.warning, trigger: alarms)
    }

    private func waitForZero() async {
        guard clock.isRunning else { return }
        let remaining = duration - clock.elapsed()
        if remaining > 0 {
            do { try await Task.sleep(for: .seconds(remaining)) } catch { return }
            alarms += 1
        }
        if !allowsOvertime { clock.pause() }
    }
}

extension View {
    func countdownAlarm(_ clock: ElapsedClock, minutes: Int, allowsOvertime: Bool) -> some View {
        modifier(CountdownAlarm(clock: clock, duration: TimeInterval(minutes * 60), allowsOvertime: allowsOvertime))
    }
}
