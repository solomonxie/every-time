import SwiftUI

struct NewTripSheet: View {
    let profile: JetLagProfile
    let onCreate: (Trip) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var origin = WorldCity.local
    @State private var destination: WorldCity?
    @State private var departure = NewTripSheet.defaultDeparture
    @State private var arrival = NewTripSheet.defaultDeparture.addingTimeInterval(10 * 3600)
    @State private var preAdjustDays = 2
    @State private var picking: End?

    private enum End: Identifiable {
        case from, to
        var id: Self { self }
    }

    private static var defaultDeparture: Date {
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .day, value: 3, to: .now) ?? .now
        return calendar.date(bySettingHour: 18, minute: 0, second: 0, of: day) ?? day
    }

    private var draft: Trip? {
        destination.map {
            Trip(origin: origin, destination: $0, departure: departure, arrival: arrival, preAdjustDays: preAdjustDays)
        }
    }

    private var problem: String? {
        guard let draft else { return nil }
        if arrival <= departure { return "Arrival is before departure" }
        if draft.zoneShiftHours == 0 { return "No time difference — no plan needed" }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    cityRow("From", city: origin) { picking = .from }
                    cityRow("To", city: destination) { picking = .to }
                }
                .listRowBackground(Theme.cardFill)

                Section {
                    DatePicker(selection: $departure) { timeLabel("Departs", city: origin) }
                        .environment(\.timeZone, origin.timeZone)
                    DatePicker(selection: $arrival) { timeLabel("Arrives", city: destination ?? origin) }
                        .environment(\.timeZone, (destination ?? origin).timeZone)
                    Stepper(value: $preAdjustDays, in: 0...3) {
                        LabeledContent("Adjust before departure") {
                            Text(preAdjustDays == 1 ? "1 day" : "\(preAdjustDays) days").monospacedDigit()
                        }
                    }
                }
                .listRowBackground(Theme.cardFill)

                if let draft {
                    Section { summary(draft) }
                        .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("New trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        guard let draft else { return }
                        onCreate(draft)
                        dismiss()
                    }
                    .disabled(draft == nil || problem != nil)
                }
            }
            .onChange(of: departure) { old, new in arrival += new.timeIntervalSince(old) }
            .sheet(item: $picking) { end in
                switch end {
                case .from: CityPickerView(excluded: Set([destination?.id].compactMap { $0 })) { origin = $0 }
                case .to: CityPickerView(excluded: [origin.id]) { destination = $0 }
                }
            }
        }
    }

    private func cityRow(_ title: String, city: WorldCity?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            LabeledContent(title) {
                HStack {
                    Text(city?.name ?? "Choose").foregroundStyle(city == nil ? .secondary : .primary)
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                }
            }
        }
        .tint(.primary)
    }

    private func timeLabel(_ title: String, city: WorldCity) -> some View {
        VStack(alignment: .leading) {
            Text(title)
            Text("\(city.name) time").font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func summary(_ draft: Trip) -> some View {
        if let problem {
            Label(problem, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.Tone.warn)
        } else {
            let plan = draft.plan(for: profile)
            let parts = [
                "\(draft.zoneShiftLabel) \(draft.zoneShiftHours > 0 ? "east" : "west")",
                plan.direction == .none ? nil : (plan.direction == .advance ? "advancing" : "delaying"),
                plan.adjustingDays > 0 ? "about \(plan.adjustingDays) days" : nil,
            ]
            Text(parts.compactMap { $0 }.joined(separator: " · "))
                .font(.clock(17, weight: .regular))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NewTripSheet(profile: JetLagProfile()) { _ in }
}
