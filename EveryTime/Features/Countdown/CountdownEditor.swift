import SwiftUI

/// Name, target and time's-up options for a new or existing countdown.
struct CountdownEditor: View {
    let isNew: Bool
    let onSave: (Countdown) -> Void
    @State private var countdown: Countdown
    @Environment(\.dismiss) private var dismiss
    @FocusState private var nameFocused: Bool

    init(countdown: Countdown, isNew: Bool, onSave: @escaping (Countdown) -> Void) {
        _countdown = State(initialValue: countdown)
        self.isNew = isNew
        self.onSave = onSave
    }

    private var trimmedName: String { countdown.name.trimmingCharacters(in: .whitespaces) }
    private var canSave: Bool { !trimmedName.isEmpty && (!isNew || countdown.target > .now) }

    /// Picker edits land on whole minutes; presets keep their exact time.
    private var target: Binding<Date> {
        Binding(get: { countdown.target }, set: { countdown.target = Self.wholeMinute($0) })
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $countdown.name, prompt: Text("e.g. New Year"))
                    .font(.cardTitle)
                    .focused($nameFocused)
                    .submitLabel(.done)
            }
            .listRowBackground(Theme.cardFill)
            Section {
                if isNew {
                    DatePicker("Ends", selection: target, in: Date.now..., displayedComponents: [.date, .hourAndMinute])
                } else {
                    DatePicker("Ends", selection: target, displayedComponents: [.date, .hourAndMinute])
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Preset.allCases) { preset in
                            Button(preset.title) { countdown.target = preset.date(from: .now) }
                                .buttonStyle(.soft)
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            }
            .listRowBackground(Theme.cardFill)
            Section {
                Toggle(isOn: $countdown[dynamicMember: \.animation].animation(.snappy)) { Label("Animation", systemImage: "sparkles") }
                if countdown.animation {
                    Picker("Effect", selection: $countdown.effect) {
                        ForEach(Countdown.Effect.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Toggle(isOn: $countdown.sound) { Label("Sound", systemImage: "speaker.wave.2") }
                Toggle(isOn: $countdown.vibrate) { Label("Vibrate", systemImage: "iphone.radiowaves.left.and.right") }
                Toggle(isOn: $countdown.notification) { Label("Notification", systemImage: "bell") }
            } header: {
                Text("When time's up")
            } footer: {
                Text("Animation, sound and vibration play while the countdown is open. A notification alerts you even when the app is closed.")
            }
            .listRowBackground(Theme.cardFill)
        }
        .scrollContentBackground(.hidden)
        .navigationTitle(isNew ? "New countdown" : "Edit countdown")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        }
        .bottomBar {
            Button("Save") {
                countdown.name = trimmedName
                onSave(countdown)
            }
            .buttonStyle(.primary)
            .disabled(!canSave)
            .opacity(canSave ? 1 : 0.4)
        }
        .sensoryFeedback(.selection, trigger: countdown.target)
        .onAppear { if isNew && countdown.name.isEmpty { nameFocused = true } }
    }

    static func wholeMinute(_ date: Date) -> Date {
        Calendar.current.dateInterval(of: .minute, for: date)?.start ?? date
    }

    enum Preset: String, CaseIterable, Identifiable {
        case tenMinutes, oneHour, tomorrowMorning, newYear
        var id: String { rawValue }

        var title: String {
            switch self {
            case .tenMinutes: "+10 min"
            case .oneHour: "+1 hour"
            case .tomorrowMorning: "Tomorrow 9 AM"
            case .newYear: "New Year's Eve midnight"
            }
        }

        func date(from now: Date, calendar: Calendar = .current) -> Date {
            switch self {
            case .tenMinutes:
                return now.addingTimeInterval(600)
            case .oneHour:
                return now.addingTimeInterval(3600)
            case .tomorrowMorning:
                let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
                return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
            case .newYear:
                let year = calendar.component(.year, from: now) + 1
                return calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? now
            }
        }
    }
}
