import SwiftUI

/// Full-screen content drawn rotated 90°, so a portrait-locked phone can be read held sideways.
/// Dark, status bar hidden, screen kept awake.
struct SidewaysScreen<Content: View>: View {
    var horizontalPadding: CGFloat = 56
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { geo in
            content
                .padding(.horizontal, horizontalPadding)
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
}

struct SidewaysCloseButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button("Close", systemImage: "xmark", action: dismiss.callAsFunction)
            .labelStyle(.iconOnly)
            .font(.system(.body, weight: .semibold))
            .frame(width: 44, height: 44)
            .background(Theme.cardFill, in: Circle())
            .buttonStyle(.plain)
    }
}
