import AVFoundation
import SwiftUI

/// Countdown ring to the alarm; turns to "Time to get up" once it rings.
struct NapInProgress: View {
    let nap: ActiveNap
    let advice: NapAdvice

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = nap.alarm.timeIntervalSince(context.date)
            let isUp = remaining <= 0
            let tonight = advice.tonight(start: nap.start, minutes: nap.minutes)
            VStack(spacing: 16) {
                ZStack {
                    ProgressRing(progress: 1 - remaining / (Double(nap.minutes) * 60),
                                 tint: isUp ? Theme.Tone.warn : .indigo, lineWidth: 10)
                    VStack(spacing: 6) {
                        TimerCaption(text: isUp ? "Time to get up" : "\(nap.minutes)-min nap",
                                     tint: isUp ? Theme.Tone.warn : nil)
                        Text(TimeText.countdown(remaining))
                            .timerDigits(size: 60)
                            .foregroundStyle(isUp ? Theme.Tone.warn : Color.primary)
                            .contentTransition(.numericText())
                        HStack(spacing: 4) {
                            Image(systemName: "alarm.fill")
                            Text(SleepNow.clock(nap.alarm))
                        }
                        .font(.label)
                            .foregroundStyle(.secondary)
                    }
                    .padding(28)
                }
                .frame(width: 250, height: 250)
                .symbolEffect(.pulse, isActive: isUp)
                NapEffectRow(symbol: "moon.zzz", text: NapAdvice.tonightText(tonight), level: tonight)
            }
            .frame(maxWidth: .infinity)
            .sensoryFeedback(.warning, trigger: isUp)
            .accessibilityElement(children: .combine)
        }
    }
}

/// How the alarm will reach you, and what could stop it.
struct NapAlarmStatus: View {
    @State private var notificationsOff = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 2)) { _ in
            VStack(alignment: .leading, spacing: 10) {
                if NapAlarm.kind == .system {
                    Label("Alarm set. It rings even in silent mode and Focus.", systemImage: "alarm.fill")
                } else {
                    Label("Rings even in silent mode. Leave Every Time open or in the background; don't swipe it away.",
                          systemImage: "alarm.fill")
                    if AVAudioSession.sharedInstance().outputVolume < 0.3 {
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
        }
        .task { notificationsOff = await NapAlarm.notificationsDenied }
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
            if let night = nap.night {
                Image(systemName: night.symbol)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(night.title)
            }
            Text("\(nap.minutes) min")
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
                Stepper("\(minutes) min", value: $minutes, in: 5...240, step: 5)
                    .monospacedDigit()
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Log a nap")
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
