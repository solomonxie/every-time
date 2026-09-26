import SwiftUI

struct JetLagPlanView: View {
    let tripID: Trip.ID
    @Stored(JetLagKey.profile) private var profile: JetLagProfile? = nil
    @Stored(JetLagKey.trips) private var trips: [Trip] = []

    var body: some View {
        if let index = trips.firstIndex(where: { $0.id == tripID }) {
            let trip = trips[index]
            PlanTimeline(trip: trip, plan: trip.plan(for: profile ?? JetLagProfile()))
                .navigationTitle("\(trip.origin.name) → \(trip.destination.name)")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            trips[index].notifications.toggle()
                            JetLagNotifications.reschedule(requestingAuthorization: true)
                        } label: {
                            Image(systemName: trip.notifications ? "bell.fill" : "bell.slash")
                        }
                        .accessibilityLabel(trip.notifications ? "Turn off reminders" : "Turn on reminders")
                        .sensoryFeedback(.selection, trigger: trip.notifications)
                    }
                }
        } else {
            ContentUnavailableView("Trip not found", systemImage: "airplane")
        }
    }
}

struct PlanTimeline: View {
    let trip: Trip
    let plan: JetLagPlan

    var body: some View {
        if plan.days.isEmpty {
            ContentUnavailableView("No plan", systemImage: "moon.zzz",
                                   description: Text("There's no time difference to adjust to."))
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        legend
                        ForEach(DayWindow.windows(for: plan)) { window in
                            VStack(alignment: .leading, spacing: Theme.spacing) {
                                DayBand(trip: trip, window: window, adjustingDays: plan.adjustingDays)
                                DayTimeline(window: window)
                            }
                        }
                    }
                    .screen()
                    .padding(.vertical)
                }
                .onAppear { proxy.scrollTo(DayTimeline.nowID, anchor: .center) }
            }
        }
    }

    private var legend: some View {
        let kinds = Set(plan.actions.map(\.kind))
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "Legend") {
                InfoButton(label: "About this plan", text: """
                    Not medical advice. The plan uses a published model of how light, sleep and \
                    melatonin shift the body clock; it's a simplification and may differ from other apps.
                    """)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ActionKind.allCases.filter(kinds.contains), id: \.self) { kind in
                        HStack(spacing: 6) {
                            ActionCapsule(kind: kind).frame(width: 8, height: 16)
                            Text(kind.legendTitle)
                        }
                        .font(.label)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.cardFill, in: Capsule())
                    }
                }
            }
        }
    }
}

private struct DayBand: View {
    let trip: Trip
    let window: DayWindow
    let adjustingDays: Int

    private var day: PlanDay { window.day }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(window.start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day(), in: window.timeZone))
                    .font(.cardTitle)
                Text(place).font(.label).foregroundStyle(.secondary)
            }
            Spacer()
            trailing.font(.label).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.cardFill)
                .overlay { Hatch().stroke(Theme.hairline, lineWidth: 1) }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var place: String {
        let range = window.lower..<window.end
        return range.contains(trip.departure) || range.contains(trip.arrival)
            ? "\(trip.origin.name) → \(trip.destination.name)"
            : trip.city(in: window.timeZone).name
    }

    @ViewBuilder
    private var trailing: some View {
        let range = window.lower..<window.end
        if day.isAdapted {
            Text("Adapted 🎉")
        } else if range.contains(trip.departure) {
            Label("Departs \(trip.departure.time(in: trip.origin.timeZone))", systemImage: "airplane.departure")
        } else if range.contains(trip.arrival) {
            Label("Lands \(trip.arrival.time(in: trip.destination.timeZone))", systemImage: "airplane.arrival")
        } else if !window.isContinuation {
            Text("Day \(day.index + 1) of \(adjustingDays)").monospacedDigit()
        }
    }
}

private struct Hatch: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        var x = -rect.height
        while x < rect.width {
            path.move(to: CGPoint(x: x, y: rect.maxY))
            path.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
            x += 10
        }
        return path
    }
}

#Preview("Eastbound") {
    PlanPreview(from: "America/Vancouver", to: "Europe/London", hours: 9.5)
}

#Preview("Westbound") {
    PlanPreview(from: "Europe/London", to: "America/Vancouver", hours: 10)
}

private struct PlanPreview: View {
    let trip: Trip

    init(from: String, to: String, hours: Double) {
        let departure = Calendar.current.date(bySettingHour: 18, minute: 40, second: 0, of: .now)!
        trip = Trip(origin: WorldCity(timeZoneIdentifier: from), destination: WorldCity(timeZoneIdentifier: to),
                    departure: departure, arrival: departure.addingTimeInterval(hours * 3600))
    }

    var body: some View {
        NavigationStack {
            PlanTimeline(trip: trip, plan: trip.plan(for: JetLagProfile(melatonin: true)))
                .navigationTitle("\(trip.origin.name) → \(trip.destination.name)")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}
