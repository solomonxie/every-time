import SwiftUI

struct JetLagProfileSheet: View {
    @State var profile: JetLagProfile
    let onSave: (JetLagProfile) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var open: Field?

    private enum Field { case bedtime, wake, age }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(profile.usualBedtime.timeOfDayText) → \(profile.usualWake.timeOfDayText)")
                            .font(.clock(26, weight: .regular))
                            .contentTransition(.numericText())
                        Spacer()
                        Text("\(profile.sleepHours.formatted(.number.precision(.fractionLength(0...1))))h")
                            .font(.cardTitle).foregroundStyle(.secondary).monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                    timeRow("Bedtime", .bedtime, minutes: $profile.usualBedtime)
                    timeRow("Wake up", .wake, minutes: $profile.usualWake)
                } header: {
                    SectionLabel("Usual sleep")
                }
                .listRowBackground(Theme.cardFill)

                Section {
                    ForEach(Chronotype.allCases) { type in
                        Button { withAnimation(.snappy) { profile.chronotype = type } } label: { chronotypeRow(type) }
                            .tint(.primary)
                    }
                } header: {
                    SectionLabel(title: "Chronotype") {
                        InfoButton(label: "About chronotype", text: """
                            Early types feel best waking early and sleepy early in the evening; \
                            late types the reverse. Most people are in between. It nudges when \
                            your body clock's low point is, and how fast it shifts.
                            """)
                    }
                }
                .listRowBackground(Theme.cardFill)

                Section {
                    UnfoldingRow(id: Field.age, open: $open) {
                        Text("Age")
                    } value: {
                        Text("\(profile.age)").monospacedDigit()
                    } picker: {
                        Picker("Age", selection: $profile.age) {
                            ForEach(12...100, id: \.self) { Text("\($0)").tag($0) }
                        }
                        .pickerStyle(.wheel)
                        .labelsHidden()
                    }
                    Picker("Sex", selection: $profile.sex) {
                        ForEach(Sex.allCases) { Text($0.title).tag($0) }
                    }
                } header: {
                    SectionLabel(title: "About you") {
                        InfoButton(label: "Why age and sex", text: """
                            The body clock shifts a little more slowly with age, and its natural day \
                            differs slightly between sexes. Both only fine-tune the plan.
                            """)
                    }
                }
                .listRowBackground(Theme.cardFill)

                Section {
                    Toggle(isOn: $profile.caffeine) { Label("Caffeine timing", systemImage: "cup.and.saucer") }
                    Toggle(isOn: $profile.melatonin) {
                        HStack(spacing: 6) {
                            Label("Melatonin", systemImage: "pills")
                            InfoButton(label: "About melatonin", text: """
                                Not medical advice. Low-dose melatonin (0.5 mg) can help shift the body \
                                clock earlier. Rules and dosing vary by country — check with a doctor first.
                                """)
                        }
                    }
                    Toggle(isOn: $profile.notifications) { Label("Reminders", systemImage: "bell") }
                } header: {
                    SectionLabel("Advice")
                }
                .listRowBackground(Theme.cardFill)
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Your sleep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .bottomBar {
                Button("Save") {
                    onSave(profile)
                    dismiss()
                }
                .buttonStyle(.primary)
            }
            .sensoryFeedback(.selection, trigger: profile)
        }
    }

    private func timeRow(_ title: String, _ field: Field, minutes: Binding<Int>) -> some View {
        UnfoldingRow(id: field, open: $open) {
            Text(title)
        } value: {
            Text(minutes.wrappedValue.timeOfDayText).monospacedDigit()
        } picker: {
            DatePicker(title, selection: minutes.timeOfDay, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
        }
    }

    private func chronotypeRow(_ type: Chronotype) -> some View {
        HStack(spacing: Theme.spacing) {
            Image(systemName: type.symbol)
                .foregroundStyle(profile.chronotype == type ? Color.accentColor : .secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(type.title)
                Text(type.blurb).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            if profile.chronotype == type {
                Image(systemName: "checkmark").fontWeight(.semibold).foregroundStyle(Color.accentColor)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(profile.chronotype == type ? .isSelected : [])
    }
}

extension Sex {
    var title: String {
        switch self {
        case .female: "Female"
        case .male: "Male"
        case .unspecified: "Not specified"
        }
    }
}

extension Chronotype {
    var title: String {
        switch self {
        case .early: "Early"
        case .intermediate: "In between"
        case .late: "Late"
        }
    }

    var blurb: String {
        switch self {
        case .early: "Up early, sleepy early"
        case .intermediate: "Most people"
        case .late: "Up late, sleepy late"
        }
    }

    var symbol: String {
        switch self {
        case .early: "sunrise"
        case .intermediate: "sun.max"
        case .late: "moon.stars"
        }
    }
}

#Preview {
    JetLagProfileSheet(profile: JetLagProfile()) { _ in }
}
