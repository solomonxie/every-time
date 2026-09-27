import SwiftUI

struct NewTripSheet: View {
    let profile: JetLagProfile
    let onCreate: (Trip) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var origin = WorldCity.local
    @State private var legs = [LegDraft(departure: NewTripSheet.defaultDeparture)]
    @State private var preAdjustDays = 2
    @State private var picking: Pick?
    @State private var open: Field?

    private static let maxLegs = 4

    private struct LegDraft: Identifiable {
        var id = UUID()
        var destination: WorldCity?
        var departure: Date
        var arrival: Date

        init(departure: Date, hours: Double = 10) {
            self.departure = departure
            arrival = departure.addingTimeInterval(hours * 3600)
        }
    }

    private enum Field: Hashable { case departure(UUID), arrival(UUID) }

    private enum Pick: Identifiable {
        case origin, leg(UUID)
        var id: String {
            switch self {
            case .origin: "origin"
            case .leg(let id): id.uuidString
            }
        }
    }

    private static var defaultDeparture: Date {
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .day, value: 3, to: .now) ?? .now
        return calendar.date(bySettingHour: 18, minute: 0, second: 0, of: day) ?? day
    }

    private var draft: Trip? {
        let chosen = legs.compactMap { leg in
            leg.destination.map { Trip.Leg(destination: $0, departure: leg.departure, arrival: leg.arrival) }
        }
        guard chosen.count == legs.count else { return nil }
        return Trip(origin: origin, legs: chosen, preAdjustDays: preAdjustDays)
    }

    private var problem: String? {
        guard let draft else { return nil }
        for (i, leg) in legs.enumerated() {
            if leg.arrival <= leg.departure {
                return legs.count == 1 ? "Arrival is before departure" : "Flight \(i + 1) lands before it departs"
            }
            if i > 0, leg.departure < legs[i - 1].arrival { return "Flight \(i + 1) departs before flight \(i) lands" }
        }
        if draft.plan(for: profile).days.isEmpty { return "No time difference — no plan needed" }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    cityRow("From", city: origin) { picking = .origin }
                    ForEach(legs) { leg in
                        cityRow(leg.id == legs.last?.id ? "To" : "Via", city: leg.destination) { picking = .leg(leg.id) }
                    }
                    routeActions
                }
                .listRowBackground(Theme.cardFill)

                ForEach(Array(legs.enumerated()), id: \.element.id) { i, leg in
                    flightSection(i, leg)
                }

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
            .sensoryFeedback(.selection, trigger: preAdjustDays)
            .sheet(item: $picking) { pick in
                switch pick {
                case .origin:
                    CityPickerView(excluded: Set([legs[0].destination?.id].compactMap { $0 })) { origin = $0 }
                case .leg(let id):
                    if let i = index(id) {
                        let next = i + 1 < legs.count ? legs[i + 1].destination?.id : nil
                        CityPickerView(excluded: Set([from(i).id, next].compactMap { $0 })) { legs[i].destination = $0 }
                    }
                }
            }
        }
    }

    private var canCreate: Bool { draft != nil && problem == nil }

    @ViewBuilder
    private var routeActions: some View {
        let canAdd = legs.count < Self.maxLegs && legs.last?.destination != nil
        let swappable = legs.count == 1 ? legs[0].destination : nil
        if canAdd || swappable != nil {
            HStack {
                if canAdd {
                    Button(action: addLeg) {
                        Label("Add a flight", systemImage: "plus").font(.subheadline)
                    }
                }
                Spacer()
                if let destination = swappable {
                    Button {
                        withAnimation(.snappy) {
                            (origin, legs[0].destination) = (destination, origin)
                        }
                    } label: {
                        Label("Swap", systemImage: "arrow.up.arrow.down").font(.subheadline)
                    }
                }
            }
            .buttonStyle(.borderless)
        }
    }

    private func flightSection(_ i: Int, _ leg: LegDraft) -> some View {
        Section {
            if i > 0, leg.departure > legs[i - 1].arrival {
                LabeledContent("Stopover in \(from(i).name)", value: duration(from: legs[i - 1].arrival, to: leg.departure))
                    .foregroundStyle(.secondary)
            }
            flightRow("Departs", .departure(leg.id), date: departure(of: leg.id), city: from(i))
            flightRow("Arrives", .arrival(leg.id), date: arrival(of: leg.id), city: leg.destination ?? from(i))
            if leg.arrival > leg.departure {
                LabeledContent("In the air", value: duration(from: leg.departure, to: leg.arrival))
                    .foregroundStyle(.secondary)
            }
        } header: {
            if legs.count == 1 {
                SectionLabel("Flight")
            } else {
                HStack {
                    SectionLabel("Flight \(i + 1)")
                    Button("Remove", role: .destructive) { removeLeg(leg.id) }
                        .font(.label)
                        .accessibilityLabel("Remove flight \(i + 1)")
                }
            }
        }
        .listRowBackground(Theme.cardFill)
    }

    private func index(_ id: UUID) -> Int? { legs.firstIndex { $0.id == id } }

    private func from(_ i: Int) -> WorldCity {
        i > 0 ? legs[i - 1].destination ?? origin : origin
    }

    /// Moving a departure also moves this arrival and every later flight, keeping lengths and stopovers.
    private func departure(of id: UUID) -> Binding<Date> {
        Binding {
            index(id).map { legs[$0].departure } ?? .now
        } set: { new in
            guard let i = index(id) else { return }
            let delta = new.timeIntervalSince(legs[i].departure)
            for j in i..<legs.count {
                legs[j].departure += delta
                legs[j].arrival += delta
            }
        }
    }

    private func arrival(of id: UUID) -> Binding<Date> {
        Binding {
            index(id).map { legs[$0].arrival } ?? .now
        } set: { new in
            if let i = index(id) { legs[i].arrival = new }
        }
    }

    private func addLeg() {
        let leg = LegDraft(departure: legs[legs.count - 1].arrival.addingTimeInterval(3 * 3600), hours: 6)
        withAnimation(.snappy) { legs.append(leg) }
        picking = .leg(leg.id)
    }

    private func removeLeg(_ id: UUID) {
        guard legs.count > 1, let i = index(id) else { return }
        withAnimation(.snappy) { _ = legs.remove(at: i) }
    }

    private func duration(from start: Date, to end: Date) -> String {
        let minutes = Int(end.timeIntervalSince(start) / 60)
        let h = minutes / 60, m = minutes % 60
        if h >= 48 { return "\(h / 24)d \(h % 24)h" }
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
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
                    Text(draft.zoneShiftHours > 0 ? "east" : draft.zoneShiftHours < 0 ? "west" : "")
                        .font(.cardTitle).foregroundStyle(.secondary)
                }
                Text(detail.compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline).foregroundStyle(.secondary)
                if let stages = stagesText(draft) {
                    Text(stages).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    /// "Short stopovers — straight to Singapore time" · "Tokyo time, then Singapore time".
    private func stagesText(_ draft: Trip) -> String? {
        guard draft.legs.count > 1 else { return nil }
        let stages = draft.stages
        if stages.count == 1 {
            return "Short stopover\(draft.legs.count > 2 ? "s" : "") — straight to \(draft.destination.name) time"
        }
        return stages.map { "\($0.destination.name) time" }.joined(separator: ", then ")
    }
}

#Preview {
    NewTripSheet(profile: JetLagProfile()) { _ in }
}
