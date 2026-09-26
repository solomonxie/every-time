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
    @State private var open: Field?

    private enum Field { case departure, arrival }

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
                    if let destination {
                        Button {
                            withAnimation(.snappy) {
                                (origin, self.destination) = (destination, origin)
                            }
                        } label: {
                            Label("Swap", systemImage: "arrow.up.arrow.down").font(.subheadline)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .listRowBackground(Theme.cardFill)

                Section {
                    flightRow("Departs", .departure, date: $departure, city: origin)
                    flightRow("Arrives", .arrival, date: $arrival, city: destination ?? origin)
                    if arrival > departure {
                        LabeledContent("In the air", value: flightDuration)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    SectionLabel("Flight")
                }
                .listRowBackground(Theme.cardFill)

                Section {
                    Picker("Start adjusting", selection: $preAdjustDays) {
                        Text("Day of").tag(0)
                        ForEach(1...3, id: \.self) { Text($0 == 1 ? "1 day" : "\($0) days").tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                } header: {
                    SectionLabel(title: "Start adjusting") {
                        InfoButton(label: "About adjusting early", text: """
                            Shifting sleep a little on the days before you fly means fewer jet-lagged \
                            days after you land. Pick "Day of" to start on departure day.
                            """)
                    }
                }
                .listRowBackground(Theme.cardFill)

                if let draft {
                    Section { summary(draft) }
                        .listRowBackground(Theme.cardFill)
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("New trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .bottomBar {
                Button("Create plan") {
                    guard let draft else { return }
                    onCreate(draft)
                    dismiss()
                }
                .buttonStyle(.primary)
                .disabled(!canCreate)
                .opacity(canCreate ? 1 : 0.4)
            }
            .onChange(of: departure) { old, new in arrival += new.timeIntervalSince(old) }
            .sensoryFeedback(.selection, trigger: preAdjustDays)
            .sheet(item: $picking) { end in
                switch end {
                case .from: CityPickerView(excluded: Set([destination?.id].compactMap { $0 })) { origin = $0 }
                case .to: CityPickerView(excluded: [origin.id]) { destination = $0 }
                }
            }
        }
    }

    private var canCreate: Bool { draft != nil && problem == nil }

    private var flightDuration: String {
        let minutes = Int(arrival.timeIntervalSince(departure) / 60)
        return minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes / 60)h \(minutes % 60)m"
    }

    private func cityRow(_ title: String, city: WorldCity?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            LabeledContent(title) {
                HStack {
                    Text(city?.name ?? "Choose").foregroundStyle(city == nil ? Color.accentColor : .primary)
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                }
            }
            .contentShape(Rectangle())
        }
        .tint(.primary)
    }

    private func flightRow(_ title: String, _ field: Field, date: Binding<Date>, city: WorldCity) -> some View {
        UnfoldingRow(id: field, open: $open) {
            VStack(alignment: .leading) {
                Text(title)
                Text("\(city.name) time").font(.caption).foregroundStyle(.secondary)
            }
        } value: {
            Text(date.wrappedValue.formatted(.dateTime.month(.abbreviated).day().hour().minute(), in: city.timeZone))
                .monospacedDigit()
        } picker: {
            DatePicker(title, selection: date)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .environment(\.timeZone, city.timeZone)
        }
    }

    @ViewBuilder
    private func summary(_ draft: Trip) -> some View {
        if let problem {
            Label(problem, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.Tone.warn)
        } else {
            let plan = draft.plan(for: profile)
            let detail = [
                plan.direction == .none ? nil : (plan.direction == .advance ? "Advancing" : "Delaying"),
                plan.adjustingDays > 0 ? "about \(plan.adjustingDays) days" : nil,
            ]
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(draft.zoneShiftLabel).font(.clock(34))
                    Text(draft.zoneShiftHours > 0 ? "east" : "west").font(.cardTitle).foregroundStyle(.secondary)
                }
                Text(detail.compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

#Preview {
    NewTripSheet(profile: JetLagProfile()) { _ in }
}
