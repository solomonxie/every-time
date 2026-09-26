import SwiftUI

struct JetLagTripsView: View {
    @Stored(JetLagKey.profile) private var profile: JetLagProfile? = nil
    @Stored(JetLagKey.trips) private var trips: [Trip] = []
    @State private var sheet: SheetKind?
    @State private var tripAfterProfile = false

    private enum SheetKind: Identifiable {
        case profile, newTrip
        var id: Self { self }
    }

    var body: some View {
        TimelineView(.everyMinute) { context in
            list(now: context.date)
        }
        .navigationTitle("Jet lag")
        .navigationDestination(for: TripRoute.self) { JetLagPlanView(tripID: $0.id) }
        .bottomBar {
            Button(action: planTrip) { Label("Plan a trip", systemImage: "airplane") }
                .buttonStyle(.primary)
        }
        .sheet(item: $sheet, onDismiss: showTripAfterProfile) { kind in
            switch kind {
            case .profile:
                JetLagProfileSheet(profile: profile ?? JetLagProfile()) { profile = $0 }
            case .newTrip:
                NewTripSheet(profile: profile ?? JetLagProfile()) { trips.append($0) }
            }
        }
        .onChange(of: trips) { JetLagNotifications.reschedule(requestingAuthorization: true) }
        .onChange(of: profile) { JetLagNotifications.reschedule(requestingAuthorization: true) }
    }

    private func list(now: Date) -> some View {
        let rows = trips
            .map { trip in (trip: trip, status: trip.status(of: trip.plan(for: profile ?? JetLagProfile()), now: now)) }
            .sorted { $0.trip.departure < $1.trip.departure }
        let upcoming = rows.filter { !$0.status.isPast }
        let past = rows.filter(\.status.isPast).reversed()

        return List {
            Section {
                Button { sheet = .profile } label: { ProfileSummary(profile: profile) }
                    .tint(.primary)
                    .listRowBackground(Theme.cardFill)
            } header: {
                SectionLabel("Your sleep")
            }

            if trips.isEmpty {
                ContentUnavailableView {
                    Label("No trips yet", systemImage: "airplane")
                } description: {
                    Text("Light, sleep and caffeine timing to beat jet lag.")
                }
                .listRowBackground(Color.clear)
            }
            section("Upcoming", rows: Array(upcoming))
            section("Past", rows: Array(past))
        }
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private func section(_ title: String, rows: [(trip: Trip, status: (text: String, isPast: Bool))]) -> some View {
        if !rows.isEmpty {
            Section {
                ForEach(rows, id: \.trip.id) { row in
                    NavigationLink(value: TripRoute(id: row.trip.id)) { TripRow(trip: row.trip, status: row.status.text) }
                }
                .onDelete { offsets in
                    let ids = Set(offsets.map { rows[$0].trip.id })
                    trips.removeAll { ids.contains($0.id) }
                }
                .listRowBackground(Theme.cardFill)
            } header: {
                SectionLabel(title)
            }
        }
    }

    private func planTrip() {
        if profile == nil {
            tripAfterProfile = true
            sheet = .profile
        } else {
            sheet = .newTrip
        }
    }

    private func showTripAfterProfile() {
        defer { tripAfterProfile = false }
        if tripAfterProfile, profile != nil { sheet = .newTrip }
    }
}

private struct TripRoute: Hashable {
    let id: Trip.ID
}

private struct ProfileSummary: View {
    let profile: JetLagProfile?

    var body: some View {
        HStack(spacing: Theme.spacing) {
            Image(systemName: "bed.double").foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                if let profile {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(profile.usualBedtime.timeOfDayText) → \(profile.usualWake.timeOfDayText)")
                            .font(.clock(20, weight: .regular))
                        Spacer(minLength: 0)
                        Text("\(profile.sleepHours.formatted(.number.precision(.fractionLength(0...1))))h")
                            .font(.label).foregroundStyle(.secondary).monospacedDigit()
                    }
                    Text(details(profile)).font(.subheadline).foregroundStyle(.secondary)
                } else {
                    Text("Set up your sleep").font(.cardTitle)
                    Text("Your usual hours shape every plan").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Edits your sleep profile")
    }

    private func details(_ profile: JetLagProfile) -> String {
        [
            profile.chronotype.title,
            profile.caffeine ? "Caffeine" : nil,
            profile.melatonin ? "Melatonin" : nil,
            profile.notifications ? "Reminders" : nil,
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }
}

private struct TripRow: View {
    let trip: Trip
    let status: String

    var body: some View {
        HStack(spacing: Theme.spacing) {
            Image(systemName: "airplane").foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(trip.origin.name) → \(trip.destination.name)").font(.cardTitle)
                Text(status).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 2) {
                Text(trip.arrival.formatted(.dateTime.month(.abbreviated).day(), in: trip.destination.timeZone))
                    .font(.clock(17, weight: .regular))
                Text(trip.zoneShiftLabel).font(.label).foregroundStyle(.secondary).monospacedDigit()
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
