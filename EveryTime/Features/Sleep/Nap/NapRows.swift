import SwiftUI

struct NapInProgress: View {
    let nap: ActiveNap
    let advice: NapAdvice

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = nap.alarm.timeIntervalSince(context.date)
            VStack(spacing: 6) {
                TimerCaption(text: "Napping since \(nap.start.formatted(date: .omitted, time: .shortened))")
                Text(TimeText.countdown(remaining))
                    .timerDigits()
                    .foregroundStyle(remaining > 0 ? Color.primary : Theme.Tone.warn)
                    .contentTransition(.numericText())
                TimerCaption(text: remaining > 0 ? "Alarm at \(nap.alarm.formatted(date: .omitted, time: .shortened))" : "Time to get up",
                             tint: remaining > 0 ? nil : Theme.Tone.warn)
                NapEffectRow(symbol: "moon.zzz", text: NapAdvice.tonightText(advice.tonight(start: nap.start, minutes: nap.minutes)),
                          level: advice.tonight(start: nap.start, minutes: nap.minutes))
                    .padding(.top, 16)
            }
            .frame(maxWidth: .infinity)
            .sensoryFeedback(.warning, trigger: remaining <= 0)
        }
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
