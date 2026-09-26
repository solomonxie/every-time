import SwiftUI

/// Full-screen readout drawn sideways, so a portrait-locked phone can be read held horizontally.
struct BigClockView<Readout: View>: View {
    let clock: ElapsedClock
    var interval: TimeInterval = 0.1
    var caption: String?
    let controls: TimerControls
    @ViewBuilder let readout: (TimeInterval) -> Readout

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geo in
            landscape
                .padding(.horizontal, 56)
                .padding(.vertical, 20)
                .frame(width: geo.size.height, height: geo.size.width)
                .rotationEffect(.degrees(90))
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .ignoresSafeArea()
        .background(.black)
        .environment(\.colorScheme, .dark)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    private var landscape: some View {
        VStack(spacing: 12) {
            if let caption, !caption.isEmpty {
                Text(caption)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            ClockTimeline(clock: clock, interval: interval, content: readout)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack {
                Button("Close", systemImage: "xmark", action: dismiss.callAsFunction)
                    .labelStyle(.iconOnly)
                    .font(.title3)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .tint(.gray)
                Spacer()
                controls
            }
            .opacity(0.7)
        }
    }
}

struct BigClockLabel: View {
    let text: String
    var note: String?

    var body: some View {
        VStack(spacing: 4) {
            Text(text)
                .font(.system(size: 400, weight: .light, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.05)
            if let note {
                Text(note).font(.title2)
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
