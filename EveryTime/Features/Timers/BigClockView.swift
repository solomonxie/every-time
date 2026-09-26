import SwiftUI

/// Full-screen readout drawn sideways, so a portrait-locked phone can be read held horizontally.
struct BigClockView<Readout: View>: View {
    let clock: ElapsedClock
    var interval: TimeInterval = 0.1
    var caption: String?
    let controls: TimerControls
    @ViewBuilder let readout: (TimeInterval) -> Readout

    var body: some View {
        SidewaysScreen { landscape }
    }

    private var landscape: some View {
        VStack(spacing: 8) {
            if let caption, !caption.isEmpty {
                Text(caption)
                    .font(.system(.title3, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            ClockTimeline(clock: clock, interval: interval, content: readout)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack(spacing: 20) {
                SidewaysCloseButton()
                Spacer()
                compactControls
            }
            .opacity(0.75)
        }
    }

    private var compactControls: TimerControls {
        var compact = controls
        compact.size = 60
        compact.spread = false
        return compact
    }
}

/// Sideways readout: thin digits scaled to fill; countdowns add a small ring + note.
struct BigClockLabel: View {
    let text: String
    var note: String?
    var progress: Double?
    var tint: Color?

    var body: some View {
        VStack(spacing: 4) {
            Text(text)
                .font(.system(size: 400, weight: .thin, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.05)
                .foregroundStyle(tint ?? .primary)
            if progress != nil || note != nil {
                HStack(spacing: 10) {
                    if let progress {
                        ProgressRing(progress: progress, tint: tint ?? .accentColor, lineWidth: 4)
                            .frame(width: 36, height: 36)
                    }
                    if let note {
                        Text(note)
                            .font(.system(.title2, design: .rounded, weight: .medium))
                            .foregroundStyle(tint ?? .secondary)
                    }
                }
            }
        }
    }
}

private struct BigClockPresenter<Cover: View>: ViewModifier {
    @ViewBuilder let cover: () -> Cover
    @State private var isPresented = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Full screen", systemImage: "arrow.up.left.and.arrow.down.right") {
                        isPresented = true
                    }
                }
            }
            .fullScreenCover(isPresented: $isPresented, content: cover)
    }
}

extension View {
    /// Toolbar button that opens a `BigClockView`.
    func bigClock<Cover: View>(@ViewBuilder cover: @escaping () -> Cover) -> some View {
        modifier(BigClockPresenter(cover: cover))
    }
}
