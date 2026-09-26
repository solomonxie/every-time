import SwiftUI

/// Round Reset/Lap (soft, left) + Start/Pause/Stop (tinted, right) pair shared by every timer.
struct TimerControls: View {
    let clock: ElapsedClock
    var stopTitle = "Pause"
    var canStart = true
    var onLap: (() -> Void)?
    var onReset: (() -> Void)?
    var size: CGFloat = 84
    var spread = true

    var body: some View {
        HStack(spacing: 20) {
            if clock.isRunning, let onLap {
                Button("Lap", action: onLap)
                    .buttonStyle(RoundButtonStyle(size: size))
            } else {
                Button("Reset") {
                    clock.reset()
                    onReset?()
                }
                .buttonStyle(RoundButtonStyle(size: size))
                .disabled(!clock.hasTime)
            }
            if spread { Spacer() }
            if clock.isRunning {
                Button(stopTitle, action: clock.pause)
                    .buttonStyle(RoundButtonStyle(size: size, tint: stopTitle == "Stop" ? Theme.Tone.bad : Theme.Tone.warn))
            } else {
                Button(clock.hasTime ? "Resume" : "Start", action: clock.start)
                    .buttonStyle(RoundButtonStyle(size: size, tint: .accentColor))
                    .disabled(!canStart)
            }
        }
        .animation(.snappy, value: clock.isRunning)
        .sensoryFeedback(.impact(weight: .medium), trigger: clock.isRunning)
    }
}

struct RoundButtonStyle: ButtonStyle {
    let size: CGFloat
    var tint: Color?

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.19, weight: .semibold, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(tint == nil ? Color.primary : .white)
            .frame(width: size, height: size)
            .background(tint ?? Color.primary.opacity(0.08), in: Circle())
            .contentShape(Circle())
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.35)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

/// Thin progress ring; `progress` 1 = full.
struct ProgressRing: View {
    let progress: Double
    var tint: Color = .accentColor
    var lineWidth: CGFloat = 6

    var body: some View {
        ZStack {
            Circle().stroke(Theme.hairline, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(lineWidth / 2)
    }
}

/// Small caption under the digits (Ready, Paused, Overtime…).
struct TimerCaption: View {
    let text: String
    var tint: Color?

    var body: some View {
        Text(text)
            .font(.label)
            .foregroundStyle(tint ?? .secondary)
            .contentTransition(.opacity)
            .animation(.snappy, value: text)
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
    /// Hero readout: thin rounded tabular digits that shrink rather than wrap.
    func timerDigits(size: CGFloat = 88) -> some View {
        font(.clock(size, weight: .thin))
            .lineLimit(1)
            .minimumScaleFactor(0.4)
    }
}
