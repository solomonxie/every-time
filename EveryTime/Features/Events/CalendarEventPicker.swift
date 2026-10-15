import EventKit
import SwiftUI

/// A calendar event reduced to what the picker shows; recurring events collapse to their series start.
struct CalendarHit: Identifiable, Sendable {
    let id: String
    let title: String
    let date: Date
    let calendarTitle: String
    let color: Color
    let isBirthdayCalendar: Bool
    var isAllDay = true

    var draft: ImportantEvent {
        ImportantEvent(
            name: title,
            date: date,
            type: EventType.guess(title: title, isBirthdayCalendar: isBirthdayCalendar),
            source: .calendar(id: id, title: title),
            hasTime: !isAllDay
        )
    }
}

enum CalendarEventIndex {
    enum Access { case granted, denied }

    static func requestAccess() async -> Access {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: return .granted
        case .denied, .restricted: return .denied
        default: return (try? await EKEventStore().requestFullAccessToEvents()) == true ? .granted : .denied
        }
    }

    /// Past 30 years to next 2, queried in ≤4-year chunks (EventKit's predicate limit), off the main thread.
    static func load(now: Date = .now) async -> [CalendarHit] {
        await Task.detached(priority: .userInitiated) {
            let store = EKEventStore()
            let calendar = Calendar.current
            guard var start = calendar.date(byAdding: .year, value: -30, to: now),
                  let end = calendar.date(byAdding: .year, value: 2, to: now) else { return [] }
            var earliest: [String: EKEvent] = [:]
            while start < end {
                let chunkEnd = min(calendar.date(byAdding: .year, value: 4, to: start) ?? end, end)
                let predicate = store.predicateForEvents(withStart: start, end: chunkEnd, calendars: nil)
                store.enumerateEvents(matching: predicate) { event, _ in
                    let id = event.calendarItemIdentifier
                    guard !(event.title ?? "").isEmpty else { return }
                    if let kept = earliest[id], kept.startDate <= event.startDate { return }
                    earliest[id] = event
                }
                start = chunkEnd
            }
            return earliest.map { id, event in
                let master = event.hasRecurrenceRules ? store.calendarItem(withIdentifier: id) as? EKEvent : nil
                return CalendarHit(
                    id: id,
                    title: event.title ?? "",
                    date: CalendarEventIndex.startDate(occurrence: event.startDate, seriesStart: master?.startDate, calendar: calendar),
                    calendarTitle: event.calendar?.title ?? "",
                    color: Color(cgColor: event.calendar?.cgColor ?? CGColor(gray: 0.5, alpha: 1)),
                    isBirthdayCalendar: event.calendar?.type == .birthday,
                    isAllDay: event.isAllDay
                )
            }
            .sorted { $0.date > $1.date }
        }.value
    }

    /// Contacts with no birth year carry a placeholder year (1604) in their Birthdays series.
    static let earliestKnownYear = 1700

    /// The series start when it's earlier and has a real year, so a 1980 birthday isn't dated to the search window's first year.
    static func startDate(occurrence: Date, seriesStart: Date?, calendar: Calendar) -> Date {
        guard let seriesStart, seriesStart < occurrence,
              calendar.component(.year, from: seriesStart) >= earliestKnownYear else { return occurrence }
        return seriesStart
    }
}

/// Root of the "From Calendar…" sheet: access → search → prefilled editor.
struct CalendarEventPicker: View {
    let onSave: (ImportantEvent) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var access: CalendarEventIndex.Access?
    @State private var hits: [CalendarHit]?
    @State private var query = ""
    @State private var picked: ImportantEvent?
    @FocusState private var searchFocused: Bool

    private static let maxResults = 100

    private var results: [CalendarHit] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty, let hits else { return [] }
        return Array(hits.lazy.filter { $0.title.localizedCaseInsensitiveContains(q) }.prefix(Self.maxResults))
    }

    var body: some View {
        content
            .navigationTitle("From Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .navigationDestination(item: $picked) { draft in
                ImportantEventEditor(event: draft, isNew: true) { onSave($0); dismiss() }
            }
            .task {
                let result = await CalendarEventIndex.requestAccess()
                access = result
                if result == .granted {
                    searchFocused = true
                    hits = await CalendarEventIndex.load()
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch access {
        case nil:
            ProgressView()
        case .denied:
            ContentUnavailableView {
                Label("Calendar access is off", systemImage: "calendar.badge.exclamationmark")
            } description: {
                Text("Settings → Privacy & Security → Calendars → Every Time")
            } actions: {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .buttonStyle(.soft)
            }
        case .granted:
            List {
                searchField.eventRow()
                if hits == nil {
                    ProgressView().frame(maxWidth: .infinity).eventRow()
                } else if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    hint("Search \(hits?.count ?? 0) events from the past 30 years").eventRow()
                } else if results.isEmpty {
                    hint("No matching events").eventRow()
                }
                ForEach(results) { hit in
                    Button { picked = hit.draft } label: { CalendarHitRow(hit: hit) }
                        .buttonStyle(.plain)
                        .eventRow(vertical: 4)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.immediately)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search events", text: $query)
                .focused($searchFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .background(Theme.cardFill, in: Capsule())
    }

    private func hint(_ text: String) -> some View {
        Text(text).font(.subheadline).foregroundStyle(.secondary).padding(.horizontal, 4)
    }
}

private struct CalendarHitRow: View {
    let hit: CalendarHit

    var body: some View {
        Card(padding: 14) {
            HStack(spacing: Theme.spacing) {
                Circle().fill(hit.color).frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(hit.title).font(.cardTitle).lineLimit(2)
                    Text("\(hit.date.formatted(.dateTime.month().day().year())) · \(hit.calendarTitle)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
    }
}
