import SwiftUI

struct ImportantEventsView: View {
    @Stored(ImportantEvent.storageKey) private var events: [ImportantEvent] = []
    @State private var isChoosingSource = false
    @State private var sheet: EventSheet?

    private static let upcomingDays = 30

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            list(now: context.date)
        }
        .overlay {
            if events.isEmpty {
                ContentUnavailableView(
                    "No important events",
                    systemImage: "star.circle",
                    description: Text("Count down to what's coming, see how long it's been since what mattered, and get a note every year.")
                )
            }
        }
        .navigationTitle("Important events")
        .bottomBar {
            Button { isChoosingSource = true } label: { Label("Add event", systemImage: "plus") }
                .buttonStyle(.primary)
                .confirmationDialog("Add event", isPresented: $isChoosingSource) {
                    Button("From Calendar…") { sheet = .calendar }
                    Button("Enter manually") { sheet = .manual }
                }
        }
        .sheet(item: $sheet) { sheet in
            NavigationStack {
                switch sheet {
                case .calendar:
                    CalendarEventPicker(onSave: save)
                case .manual:
                    ImportantEventEditor(event: ImportantEvent(name: "", date: .now), isNew: true, onSave: save)
                case .edit(let event):
                    ImportantEventEditor(event: event, isNew: false, onSave: save)
                }
            }
        }
        .sensoryFeedback(.success, trigger: events.count) { old, new in new > old }
    }

    private func list(now: Date) -> some View {
        let infos = events.map { EventInfo(event: $0, now: now) }
        let countdowns = infos.filter(\.isFuture).sorted { $0.event.date < $1.event.date }
        let past = infos.filter { !$0.isFuture }
        let today = past.filter(\.isToday)
        let upcoming = past
            .filter { !$0.isToday && (1...Self.upcomingDays).contains($0.daysUntilNext) }
            .sorted { $0.daysUntilNext < $1.daysUntilNext }

        return List {
            if !countdowns.isEmpty {
                SectionLabel("Countdown").eventRow(vertical: 2)
                ForEach(countdowns) { info in
                    Button { sheet = .edit(info.event) } label: { CountdownCard(info: info, now: now) }
                        .buttonStyle(.plain)
                        .eventRow(vertical: 4)
                }
                .onDelete { delete(countdowns, at: $0) }
            }
            if !today.isEmpty {
                SectionLabel("Today").eventRow(vertical: 2)
                ForEach(today) { info in
                    Button { sheet = .edit(info.event) } label: { TodayCard(info: info) }
                        .buttonStyle(.plain)
                        .eventRow()
                }
            }
            if !upcoming.isEmpty {
                SectionLabel("Upcoming").padding(.top, today.isEmpty ? 0 : 12).eventRow(vertical: 2)
                ForEach(upcoming) { info in
                    Button { sheet = .edit(info.event) } label: { UpcomingRow(info: info) }
                        .buttonStyle(.plain)
                        .eventRow(vertical: 4)
                }
            }
            if !past.isEmpty {
                SectionLabel(title: "Since") {
                    Text("\(past.count)").font(.label).foregroundStyle(.tertiary)
                }
                .padding(.top, countdowns.isEmpty && today.isEmpty && upcoming.isEmpty ? 0 : 12)
                .eventRow(vertical: 2)
            }
            ForEach(past) { info in
                Button { sheet = .edit(info.event) } label: { EventCard(info: info) }
                    .buttonStyle(.plain)
                    .eventRow(vertical: 4)
            }
            .onDelete { delete(past, at: $0) }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func delete(_ shown: [EventInfo], at offsets: IndexSet) {
        let ids = Set(offsets.map { shown[$0].id })
        events.removeAll { ids.contains($0.id) }
        ImportantEventNotifications.reschedule()
    }

    private func save(_ event: ImportantEvent) {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index] = event
        } else {
            events.append(event)
        }
        sheet = nil
        ImportantEventNotifications.reschedule(requestingAuthorization: event.notify)
    }
}

private enum EventSheet: Identifiable {
    case calendar, manual
    case edit(ImportantEvent)

    var id: String {
        switch self {
        case .calendar: "calendar"
        case .manual: "manual"
        case .edit(let event): event.id.uuidString
        }
    }
}

/// Derived numbers for one event at `now`.
private struct EventInfo: Identifiable {
    let event: ImportantEvent
    let elapsed: Anniversary.Elapsed
    let next: Date?
    let daysUntilNext: Int
    let yearsAtNext: Int

    let isFuture: Bool

    var id: UUID { event.id }
    var isToday: Bool { next != nil && daysUntilNext == 0 }

    init(event: ImportantEvent, now: Date) {
        self.event = event
        isFuture = event.isFuture(at: now)
        elapsed = Anniversary.elapsed(since: event.date, to: now)
        next = Anniversary.next(of: event.date, from: now)
        daysUntilNext = next.map { Anniversary.days(from: now, to: $0) } ?? .max
        yearsAtNext = next.map { Anniversary.years(at: $0, since: event.date) } ?? 0
    }

    var phrase: String {
        Anniversary.phrase(event.type, years: yearsAtNext, name: event.name, isToday: isToday)
    }

    var countdown: String {
        switch daysUntilNext {
        case 0: "Today"
        case 1: "Tomorrow"
        default: "in \(daysUntilNext) days"
        }
    }
}

extension EventType {
    var tint: Color {
        switch self {
        case .birthday: .pink
        case .anniversary, .relationship: .red
        case .wedding: .purple
        case .memorial: .gray
        case .milestone: .orange
        case .other: .accentColor
        }
    }
}

private struct TypeIcon: View {
    let type: EventType
    var size: CGFloat = 36

    var body: some View {
        Image(systemName: type.symbol)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(type.tint)
            .frame(width: size, height: size)
            .background(type.tint.opacity(0.14), in: Circle())
    }
}

private struct TodayCard: View {
    let info: EventInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(ImportantEventCopy.todayTitle(info.event, years: info.yearsAtNext))
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
            Text("Since \(info.event.date.formatted(.dateTime.month().day().year()))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .contentShape(Rectangle())
    }
}

private struct UpcomingRow: View {
    let info: EventInfo

    var body: some View {
        Card(padding: 14) {
            HStack(spacing: Theme.spacing) {
                TypeIcon(type: info.event.type, size: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(info.event.name).font(.cardTitle).lineLimit(1)
                    Text(info.phrase).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
                Text(info.countdown).font(.label).foregroundStyle(.tint)
            }
        }
        .contentShape(Rectangle())
    }
}

private struct CountdownCard: View {
    let info: EventInfo
    let now: Date

    var body: some View {
        let left = Anniversary.countdown(to: info.event.date, from: now, hasTime: info.event.hasTime)
        Card {
            HStack(alignment: .top, spacing: Theme.spacing) {
                TypeIcon(type: info.event.type)
                VStack(alignment: .leading, spacing: 4) {
                    Text(info.event.name).font(.cardTitle).lineLimit(2)
                    Text(info.event.date, format: info.event.hasTime
                         ? .dateTime.weekday(.abbreviated).month().day().year().hour().minute()
                         : .dateTime.weekday(.abbreviated).month().day().year())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(left.value)").font(.clock(40)).contentTransition(.numericText())
                        Text("\(left.unit) to go").font(.label).foregroundStyle(.secondary)
                    }
                    Text(left.detail).font(.caption).foregroundStyle(.secondary)
                }
                .foregroundStyle(.tint)
            }
            if !info.event.notify {
                Label("No reminder", systemImage: "bell.slash").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .animation(.snappy, value: left)
        .contentShape(Rectangle())
    }
}

private struct EventCard: View {
    let info: EventInfo

    private var caption: String? {
        let days = abs(info.elapsed.days)
        let total = info.elapsed.parts.count > 1 ? "\(days.formatted()) days" : nil
        return [info.elapsed.days < 0 ? "to go" : nil, total].compactMap { $0 }.joined(separator: " · ").nilIfEmpty
    }

    var body: some View {
        Card {
            HStack(alignment: .top, spacing: Theme.spacing) {
                TypeIcon(type: info.event.type)
                VStack(alignment: .leading, spacing: 4) {
                    Text(info.event.name).font(.cardTitle).lineLimit(2)
                    Text(info.event.date, format: .dateTime.month().day().year())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        ForEach(info.elapsed.parts, id: \.unit) { part in
                            Text("\(part.value)").font(.clock(34))
                            Text(part.unit).font(.label).foregroundStyle(.secondary)
                        }
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    if let caption { Text(caption).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
                }
                .layoutPriority(1)
            }
            if let next = info.next {
                HStack(spacing: 6) {
                    if !info.event.notify { Image(systemName: "bell.slash").font(.caption) }
                    Text("\(info.phrase) · \(next.formatted(.dateTime.month().day().year())) · \(info.countdown)")
                        .lineLimit(2)
                }
                .font(.footnote)
                .foregroundStyle(info.isToday ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            }
        }
        .contentShape(Rectangle())
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

extension View {
    /// List row without chrome, so cards keep swipe-to-delete.
    func eventRow(vertical: CGFloat = 6) -> some View {
        listRowInsets(EdgeInsets(top: vertical, leading: Theme.padding, bottom: vertical, trailing: Theme.padding))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

#Preview {
    NavigationStack { ImportantEventsView() }
}
