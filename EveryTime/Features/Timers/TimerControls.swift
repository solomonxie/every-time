import SwiftUI

/// Reset/Lap + Start/Stop pair shared by every timer.
struct TimerControls: View {
    let clock: ElapsedClock
    var stopTitle = "Pause"
    var canStart = true
    var onLap: (() -> Void)?
    var onReset: (() -> Void)?

    var body: some View {
        HStack(spacing: 24) {
            if clock.isRunning, let onLap {
                button("Lap", tint: .gray, action: onLap)
            } else {
                button("Reset", tint: .gray) {
                    clock.reset()
                    onReset?()
                }
                .disabled(!clock.hasTime)
            }
            if clock.isRunning {
                button(stopTitle, tint: stopTitle == "Stop" ? .red : .orange, action: clock.pause)
            } else {
                button("Start", tint: .green, action: clock.start)
                    .disabled(!canStart)
            }
        }
        .sensoryFeedback(.impact, trigger: clock.isRunning)
    }

    private func button(_ title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(width: 88, height: 36)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .tint(tint)
    }
}

/// Redraws only while the clock runs.
struct ClockTimeline<Content: View>: View {
    let clock: ElapsedClock
    var interval: TimeInterval = 0.1
    @ViewBuilder let content: (TimeInterval) -> Content

    var body: some View {
        TimelineView(.animation(minimumInterval: interval, paused: !clock.isRunning)) { context in
            content(clock.elapsed(at: context.date))
        }
    }
}

extension View {
    func timerDigits(size: CGFloat = 64) -> some View {
        font(.system(size: size, weight: .light, design: .rounded))
            .monospacedDigit()
    }
}
