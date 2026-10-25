import AVFoundation
import SwiftUI

/// How the alarm will reach you, and what could stop it.
struct NapAlarmStatus: View {
    @State private var notificationsOff = false
    @State private var volumeLow = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if NapAlarm.kind == .system {
                Label("Alarm set. It rings even in silent mode and Focus.", systemImage: "alarm.fill")
            } else {
                Label("Rings even in silent mode. Leave Every Time open or in the background; don't swipe it away.",
                      systemImage: "alarm.fill")
                if volumeLow {
                    Label("Volume is low. Turn it up so the alarm is loud.", systemImage: "speaker.wave.1.fill")
                        .foregroundStyle(Theme.Tone.warn)
                }
                if notificationsOff {
                    Label("Notifications are off, so a closed app can't wake you.", systemImage: "bell.slash.fill")
                        .foregroundStyle(Theme.Tone.warn)
                    Button("Turn on notifications") {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderless)
                    .fontWeight(.semibold)
                }
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        // Asking the audio session blocks; once, off the main thread, is enough.
        .task {
            notificationsOff = await NapAlarm.notificationsDenied
            volumeLow = await Task.detached { AVAudioSession.sharedInstance().outputVolume < 0.3 }.value
        }
    }
}

/// "Mid-cycle · 2 cycles done · 40 min to the next end".
struct WakeCheckRow: View {
    let check: WakeCheck

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: check.isAtCycleEnd ? "checkmark.circle.fill" : "circle.dotted")
                .foregroundStyle(check.isAtCycleEnd ? Theme.Tone.good : Theme.Tone.warn)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(check.headline).font(.subheadline.weight(.semibold))
                Text(check.detail).font(.footnote).foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

struct NapEffectRow: View {
    let symbol: String
    let text: String
    let level: NapAdvice.Level

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).foregroundStyle(level.tint).frame(width: 22)
            Text(text).font(.subheadline)
        }
    }
}

/// One history line; nights and naps share the same columns.
struct SleepHistoryRow<Lead: View>: View {
    let date: Date
    let detail: String
    var energy: Int? = nil
    let duration: String
    var note: String? = nil
    @ViewBuilder let lead: () -> Lead

    var body: some View {
        HStack(spacing: 12) {
            lead().frame(width: 34, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                Text(date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                    .font(.system(.body, design: .rounded))
                Text(detail)
                    .font(.label)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .layoutPriority(1)
            Spacer(minLength: 4)
            Image(systemName: Nap.energySymbol(energy ?? 0))
                .font(.subheadline)
                .foregroundStyle(EnergyChart.tint(energy ?? 0))
                .opacity(energy == nil ? 0 : 1)
                .frame(width: 32)
                .accessibilityLabel(energy.map { "Felt \(Nap.energyTitle($0).lowercased())" } ?? "")
                .accessibilityHidden(energy == nil)
            VStack(alignment: .trailing, spacing: 1) {
                Text(duration).font(.clock(20, weight: .regular))
                if let note { Text(note).font(.label).foregroundStyle(.secondary) }
            }
            .lineLimit(1)
            .fixedSize()
            .frame(minWidth: 84, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

struct NapRow: View {
    let nap: Nap
    let level: NapAdvice.Level

    var body: some View {
        SleepHistoryRow(
            date: nap.start,
            detail: "\(SleepNow.clock(nap.start)) – \(SleepNow.clock(nap.end))",
            energy: nap.energy,
            duration: "\(nap.minutes) min"
        ) {
            Image(systemName: "sofa.fill").font(.title3).frame(width: 30, height: 22).foregroundStyle(level.tint)
        }
    }
}

/// A sleep the app didn't see, logged after: in-bed times and how rested you feel.
struct LogNapSheet: View {
    let onSave: (Nap) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var start: Date
    @State private var end: Date
    @State private var energy: Int?

    init(draft: Nap? = nil, onSave: @escaping (Nap) -> Void) {
        let end = min(draft?.end ?? .now, .now)
        self.onSave = onSave
        _start = State(initialValue: min(draft?.start ?? end.addingTimeInterval(-Double(NapAdvice.suggestedMinutes) * 60), end))
        _end = State(initialValue: end)
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Went to bed", selection: $start, in: ...Date.now)
                DatePicker("Woke up", selection: $end, in: start...Date.now)
                LabeledContent(Night.isNap(end.timeIntervalSince(start)) ? "Nap" : "Night", value: ActivityLog.duration(max(0, end.timeIntervalSince(start))))
                Section {
                    SleepFeedback(energy: $energy).padding(.vertical, 4)
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Log sleep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .bottomBar {
                Button("Save") {
                    onSave(Nap(start: start, end: end, energy: energy))
                    dismiss()
                }
                .buttonStyle(.primary)
                .disabled(end <= start)
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Change a logged sleep's times and how it went, or remove it.
struct SleepEditor: View {
    @State var nap: Nap
    let onSave: (Nap) -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var confirmsDelete = false

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Went to bed", selection: $nap.start, in: ...Date.now)
                DatePicker("Woke up", selection: $nap.end, in: nap.start...Date.now)
                LabeledContent(nap.isNight ? "Night" : "Nap", value: ActivityLog.duration(nap.duration))
                Section {
                    SleepFeedback(energy: $nap.energy).padding(.vertical, 4)
                }
                Section {
                    Button("Remove", role: .destructive) { confirmsDelete = true }
                        .confirmationDialog("Remove this sleep?", isPresented: $confirmsDelete, titleVisibility: .visible) {
                            Button("Remove", role: .destructive) {
                                onDelete()
                                dismiss()
                            }
                        }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Edit sleep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(nap)
                        dismiss()
                    }
                    .disabled(nap.end <= nap.start)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// How rested you feel after any sleep, nap or night. Tap again to clear.
struct SleepFeedback: View {
    var question = "How rested do you feel?"
    @Binding var energy: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question).font(.subheadline.weight(.medium))
            HStack(spacing: 6) {
                ForEach(Array(Nap.energyRange), id: \.self) { level in
                    let isOn = energy == level
                    let tint = EnergyChart.tint(level)
                    Button { energy = isOn ? nil : level } label: {
                        Text(Nap.energyTitle(level))
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .foregroundStyle(isOn ? Color.white : tint)
                            .background(isOn ? AnyShapeStyle(tint) : AnyShapeStyle(tint.opacity(0.15)),
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Nap.energyTitle(level))
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
        }
    }
}
