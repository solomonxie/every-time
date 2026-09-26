import SwiftUI

struct JetLagProfileSheet: View {
    @State var profile: JetLagProfile
    let onSave: (JetLagProfile) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $profile.age, in: 12...100) {
                        LabeledContent("Age") {
                            Text("\(profile.age)").font(.clock(20, weight: .regular))
                        }
                    }
                    LabeledContent("Sex") {
                        Picker("Sex", selection: $profile.sex) {
                            ForEach(Sex.allCases) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .fixedSize()
                    }
                    VStack(alignment: .leading) {
                        HStack(spacing: 6) {
                            Text("Chronotype")
                            InfoButton(label: "About chronotype", text: """
                                Early types feel best waking early and sleepy early in the evening; \
                                late types the reverse. Most people are in between. It nudges when \
                                your body clock's low point is, and how fast it shifts.
                                """)
                        }
                        Picker("Chronotype", selection: $profile.chronotype) {
                            ForEach(Chronotype.allCases) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                    DatePicker("Usual bedtime", selection: time($profile.usualBedtime), displayedComponents: .hourAndMinute)
                    DatePicker("Usual wake time", selection: time($profile.usualWake), displayedComponents: .hourAndMinute)
                }
                .listRowBackground(Theme.cardFill)

                Section {
                    Toggle(isOn: $profile.melatonin) {
                        HStack(spacing: 6) {
                            Text("Melatonin")
                            InfoButton(label: "About melatonin", text: """
                                Not medical advice. Low-dose melatonin (0.5 mg) can help shift the body \
                                clock earlier. Rules and dosing vary by country — check with a doctor first.
                                """)
                        }
                    }
                    Toggle("Caffeine", isOn: $profile.caffeine)
                    Toggle("Notifications", isOn: $profile.notifications)
                } header: {
                    SectionLabel("Advice")
                }
                .listRowBackground(Theme.cardFill)
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("About you")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(profile)
                        dismiss()
                    }
                }
            }
        }
    }

    private func time(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: minutes.wrappedValue / 60, minute: minutes.wrappedValue % 60,
                                  second: 0, of: .now) ?? .now
        } set: {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: $0)
            minutes.wrappedValue = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        }
    }
}

private extension Sex {
    var label: String {
        switch self {
        case .female: "Female"
        case .male: "Male"
        case .unspecified: "—"
        }
    }
}

private extension Chronotype {
    var label: String {
        switch self {
        case .early: "Early"
        case .intermediate: "In between"
        case .late: "Late"
        }
    }
}

#Preview {
    JetLagProfileSheet(profile: JetLagProfile()) { _ in }
}
