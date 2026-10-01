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

struct NapRow: View {
    let nap: Nap
    let level: NapAdvice.Level

    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(level.tint).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 3) {
                Text(nap.start, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                    .font(.system(.body, design: .rounded))
                Text("\(nap.start.formatted(date: .omitted, time: .shortened)) – \(nap.end.formatted(date: .omitted, time: .shortened))")
                    .font(.label)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let energy = nap.energy {
                Text(Nap.energyTitle(energy))
                    .font(.label)
                    .foregroundStyle(.secondary)
            }
            if let night = nap.night {
                Image(systemName: night.symbol)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(night.title)
            }
            Text(nap.isNight ? NapAdvice.hours((nap.duration / 60).rounded() / 60) : "\(nap.minutes) min")
                .font(.clock(20, weight: .regular))
        }
    }
}

struct LogNapSheet: View {
    let onSave: (Nap) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var start = Calendar.current.date(byAdding: .minute, value: -30, to: .now) ?? .now
    @State private var minutes = NapAdvice.suggestedMinutes

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Fell asleep", selection: $start, in: ...Date.now)
                Stepper(minutes < 60 ? "\(minutes) min" : NapAdvice.hours(Double(minutes) / 60), value: $minutes, in: 5...720, step: 5)
                    .monospacedDigit()
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Log sleep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .bottomBar {
                Button("Save") {
                    onSave(Nap(start: start, end: start.addingTimeInterval(Double(minutes) * 60)))
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
