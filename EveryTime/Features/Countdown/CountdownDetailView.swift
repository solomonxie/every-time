import SwiftUI

/// Big value for the focus unit, small-caps unit label, smaller lower units beneath.
struct CountdownReadoutView: View {
    let readout: CountdownReadout
    var big: CGFloat = 120
    var small: CGFloat = 40
    var tint: Color = .primary

    var body: some View {
        VStack(spacing: small * 0.2) {
            HStack(alignment: .firstTextBaseline, spacing: small * 0.25) {
                Text("\(readout.value)")
                    .font(.clock(big, weight: .thin))
                    .contentTransition(.numericText(countsDown: true))
                Text(readout.label.uppercased())
                    .font(.system(size: max(13, small * 0.4), weight: .medium, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(.secondary)
            }
            if !readout.rest.isEmpty {
                Text(readout.rest)
                    .font(.clock(small))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText(countsDown: true))
            }
        }
        .foregroundStyle(tint)
        .lineLimit(1)
        .minimumScaleFactor(0.1)
        .animation(.snappy, value: readout)
        .accessibilityElement(children: .combine)
    }
}

struct CountdownDetailView: View {
    let id: UUID
    @Stored(Countdown.storageKey) private var countdowns: [Countdown] = []
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false
    @State private var isFullScreen = false
    @State private var celebrating = false

    private var countdown: Countdown? { countdowns.first { $0.id == id } }

    var body: some View {
        Group {
            if let countdown {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    content(countdown, now: context.date)
                }
                .task(id: countdown) { await watch(countdown) }
            } else {
                ContentUnavailableView("Countdown deleted", systemImage: "hourglass")
            }
        }
        .overlay {
            if celebrating, !isFullScreen, let countdown {
                CelebrationOverlay(effect: countdown.effect, title: countdown.name) { celebrating = false }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: celebrating)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Full screen", systemImage: "arrow.up.left.and.arrow.down.right") { isFullScreen = true }
                    .disabled(countdown == nil)
            }
        }
        .fullScreenCover(isPresented: $isFullScreen) {
            if let countdown {
                CountdownSidewaysView(countdown: countdown, celebrating: $celebrating)
            }
        }
        .sheet(isPresented: $isEditing) {
            if let countdown {
                NavigationStack { CountdownEditor(countdown: countdown, isNew: false, onSave: save) }
            }
        }
    }

    private func content(_ countdown: Countdown, now: Date) -> some View {
        let finished = countdown.isFinished(at: now)
        return VStack(spacing: Theme.spacing) {
            VStack(spacing: 4) {
                Text(countdown.name)
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text(countdown.target, format: .dateTime.weekday(.wide).month().day().year().hour().minute())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, Theme.padding)
            Spacer(minLength: 0)
            if finished {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 64, weight: .thin))
                        .foregroundStyle(.tint)
                    Text("Time's up").font(.clock(48, weight: .thin))
                    Text("Finished \(countdown.target.formatted(.dateTime.month().day().hour().minute()))")
                        .font(.label)
                        .foregroundStyle(.secondary)
                }
            } else {
                CountdownReadoutView(readout: CountdownReadout(remaining: countdown.remaining(at: now)))
            }
            Spacer(minLength: 0)
            ProgressView(value: countdown.progress(at: now))
                .tint(finished ? Theme.Tone.good : .accentColor)
                .padding(.horizontal, 4)
            HStack(spacing: Theme.spacing) {
                Button { isEditing = true } label: { Label("Edit", systemImage: "pencil") }
                if finished {
                    Button { replay(countdown) } label: { Label("Replay", systemImage: "play.fill") }
                }
            }
            .buttonStyle(.soft)
            .padding(.bottom, Theme.spacing)
        }
        .screen()
    }

    /// Fires once when a running countdown reaches zero while this screen (or its sideways view) is up.
    private func watch(_ countdown: Countdown) async {
        guard !countdown.isFinished(at: .now) else { return }
        while !Task.isCancelled {
            let left = countdown.remaining(at: .now)
            if left <= 0 { break }
            try? await Task.sleep(for: .seconds(min(left, 0.25)))
        }
        guard !Task.isCancelled, !CountdownFinish.hasFired(countdown.id) else { return }
        CountdownFinish.markFired(countdown.id)
        celebrate(countdown)
    }

    private func replay(_ countdown: Countdown) { celebrate(countdown) }

    private func celebrate(_ countdown: Countdown) {
        CountdownFinish.play(countdown)
        if countdown.animation { celebrating = true }
    }

    private func save(_ edited: Countdown) {
        if let index = countdowns.firstIndex(where: { $0.id == edited.id }) {
            if countdowns[index].target != edited.target { CountdownFinish.reset(edited.id) }
            countdowns[index] = edited
        }
        isEditing = false
        CountdownNotifications.reschedule(requestingAuthorization: edited.notification)
    }
}

/// The same readout drawn sideways and scaled to fill.
struct CountdownSidewaysView: View {
    let countdown: Countdown
    @Binding var celebrating: Bool

    var body: some View {
        SidewaysScreen {
            VStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    SidewaysCloseButton()
                    Text(countdown.name)
                        .font(.system(.title3, design: .rounded, weight: .medium))
                        .lineLimit(1)
                    Spacer()
                    Text(countdown.target, format: .dateTime.month().day().hour().minute())
                        .font(.label)
                        .foregroundStyle(.secondary)
                }
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    if countdown.isFinished(at: context.date) {
                        Text("Time's up")
                            .font(.system(size: 300, weight: .thin, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.1)
                            .foregroundStyle(.tint)
                    } else {
                        CountdownReadoutView(readout: CountdownReadout(remaining: countdown.remaining(at: context.date)),
                                             big: 260, small: 72)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .overlay {
                if celebrating {
                    CelebrationOverlay(effect: countdown.effect, title: countdown.name) { celebrating = false }
                        .padding(.horizontal, -56)
                        .padding(.vertical, -20)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: celebrating)
        }
    }
}
