import SwiftUI

/// Interview (stops at zero) and Rehearsal (keeps counting as overtime).
struct CountdownView: View {
    let kind: TimerKind
    let clock: ElapsedClock
    @Binding var minutes: Int
    var step = 5

    private var allowsOvertime: Bool { kind == .rehearsal }
    private var duration: TimeInterval { TimeInterval(minutes * 60) }

    var body: some View {
        VStack(spacing: 28) {
            ClockTimeline(clock: clock) { elapsed in
                dial(phase(elapsed))
            }
            .frame(maxWidth: 320)
            .padding(.horizontal, Theme.padding + 12)
            .padding(.top, 32)

            DurationStepper(minutes: $minutes, step: step)
                .disabled(clock.isRunning)

            Spacer(minLength: 0)

            controls
                .padding(.horizontal, Theme.padding)
                .padding(.bottom, 24)
        }
        .navigationTitle(kind.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .bigClock {
            BigClockView(clock: clock, controls: controls) { elapsed in
                let phase = phase(elapsed)
                BigClockLabel(text: phase.readout, note: phase.note, progress: phase.progress, tint: phase.tint)
            }
        }
    }

    private var controls: TimerControls {
        TimerControls(clock: clock, canStart: allowsOvertime || clock.elapsed() < duration)
    }

    private func phase(_ elapsed: TimeInterval) -> CountdownPhase {
        CountdownPhase(remaining: duration - elapsed, duration: duration, allowsOvertime: allowsOvertime)
    }

    private func dial(_ phase: CountdownPhase) -> some View {
        ZStack {
            ProgressRing(progress: phase.progress, tint: phase.tint ?? .accentColor)
            VStack(spacing: 6) {
                Text(phase.readout)
                    .timerDigits(size: 72)
                    .foregroundStyle(phase.tint ?? .primary)
                    .contentTransition(.numericText(countsDown: !phase.isDone))
                    .animation(.snappy, value: phase.readout)
                TimerCaption(text: caption(phase), tint: phase.tint)
            }
            .padding(36)
        }
        .aspectRatio(1, contentMode: .fit)
        .animation(.snappy, value: phase.tint)
    }

    private func caption(_ phase: CountdownPhase) -> String {
        if let note = phase.note { return note }
        if clock.isRunning {
            return "Ends " + Date.now.addingTimeInterval(phase.remaining).formatted(date: .omitted, time: .shortened)
        }
        return clock.hasTime ? "Paused" : "Ready"
    }
}

private struct CountdownPhase {
    let remaining: TimeInterval
    let duration: TimeInterval
    let allowsOvertime: Bool

    var isDone: Bool { remaining <= 0 }

    var readout: String {
        !isDone || allowsOvertime ? TimeText.countdown(remaining) : TimeText.clock(0)
    }

    var progress: Double { isDone || duration <= 0 ? 1 : remaining / duration }

    /// nil while counting down; orange in overtime, red at time's up.
    var tint: Color? {
        guard isDone else { return nil }
        return allowsOvertime ? Theme.Tone.warn : Theme.Tone.bad
    }

    var note: String? {
        guard isDone else { return nil }
        return allowsOvertime ? "Overtime" : "Time's up"
    }
}

/// Compact `− 45 min +` pill.
private struct DurationStepper: View {
    @Binding var minutes: Int
    let step: Int

    @Environment(\.isEnabled) private var isEnabled
    private var range: ClosedRange<Int> { step...180 }

    var body: some View {
        HStack(spacing: 4) {
            button("Shorter", symbol: "minus", to: minutes - step)
            Text("\(minutes) min")
                .font(.clock(17, weight: .medium))
                .contentTransition(.numericText(value: Double(minutes)))
                .frame(minWidth: 72)
            button("Longer", symbol: "plus", to: minutes + step)
        }
        .padding(.horizontal, 4)
        .background(Theme.cardFill, in: Capsule())
        .opacity(isEnabled ? 1 : 0.4)
        .animation(.snappy, value: minutes)
        .sensoryFeedback(.selection, trigger: minutes)
    }

    private func button(_ title: String, symbol: String, to value: Int) -> some View {
        Button(title, systemImage: symbol) { minutes = value }
            .labelStyle(.iconOnly)
            .font(.system(.body, weight: .semibold))
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .buttonStyle(.plain)
            .disabled(!range.contains(value))
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
