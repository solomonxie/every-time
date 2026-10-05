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
    var symbol: Nap.Night? = nil
    let duration: String
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
            }
            Spacer(minLength: 4)
            Text(energy.map(Nap.energyTitle) ?? "")
                .font(.label)
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .trailing)
            Image(systemName: symbol?.symbol ?? "circle")
                .foregroundStyle(.secondary)
                .opacity(symbol == nil ? 0 : 1)
                .frame(width: 24)
                .accessibilityLabel(symbol?.title ?? "")
            Text(duration)
                .font(.clock(20, weight: .regular))
                .frame(width: 76, alignment: .trailing)
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
            detail: "\(nap.start.formatted(date: .omitted, time: .shortened)) – \(nap.end.formatted(date: .omitted, time: .shortened))",
            energy: nap.energy,
            symbol: nap.night,
            duration: nap.isNight ? NapAdvice.hours((nap.duration / 60).rounded() / 60) : "\(nap.minutes) min"
        ) {
            Circle().fill(level.tint).frame(width: 8, height: 8)
        }
    }
}

struct LogNapSheet: View {
    let onSave: (Nap) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var start = Calendar.current.date(byAdding: .minute, value: -30, to: .now) ?? .now
    @State private var minutes = NapAdvice.suggestedMinutes
    @State private var natural = true

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Fell asleep", selection: $start, in: ...Date.now)
                Stepper(minutes < 60 ? "\(minutes) min" : NapAdvice.hours(Double(minutes) / 60), value: $minutes, in: 5...720, step: 5)
                    .monospacedDigit()
                Toggle(isOn: $natural) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Woke on my own")
                        Text("Not by an alarm — these teach your cycle length").font(.caption).foregroundStyle(.secondary)
                    }
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
                    onSave(Nap(start: start, end: start.addingTimeInterval(Double(minutes) * 60), natural: natural))
                    dismiss()
                }
                .buttonStyle(.primary)
            }
        }
        .presentationDetents([.medium])
    }
}

extension View {
    func napRow() -> some View {
        listRowInsets(EdgeInsets(top: 10, leading: Theme.padding, bottom: 10, trailing: Theme.padding))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

/// Change a logged sleep's times, whether you woke on your own, or remove it.
struct SleepEditor: View {
    @State var nap: Nap
    let onSave: (Nap) -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var confirmsDelete = false

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Fell asleep", selection: $nap.start, in: ...Date.now)
                DatePicker("Woke up", selection: $nap.end, in: nap.start...Date.now)
                LabeledContent(nap.isNight ? "Night" : "Nap", value: ActivityLog.duration(nap.duration))
                Toggle(isOn: Binding(get: { nap.natural == true }, set: { nap.natural = $0 })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Woke on my own")
                        Text("Not by an alarm — these teach your cycle length").font(.caption).foregroundStyle(.secondary)
                    }
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
