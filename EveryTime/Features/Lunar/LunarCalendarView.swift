import EventKit
import SwiftUI

struct LunarCalendarView: View {
    @Stored("calendar.lunar") private var events: [LunarEvent] = []
    @State private var convertDate = Date.now
    @State private var isAdding = false
    @State private var calendarMessage: String?

    var body: some View {
        List {
            TodayCard().cardRow()
            ConverterCard(date: $convertDate).cardRow()
            SectionLabel(title: "Events") {
                if !events.isEmpty { Text("\(events.count)").font(.label).foregroundStyle(.tertiary) }
            }
            .padding(.top, 12)
            .cardRow(vertical: 2)
            ForEach(events) { LunarEventRow(event: $0).cardRow(vertical: 4) }
                .onDelete { events.remove(atOffsets: $0) }
            if events.isEmpty {
                Label("No events yet — add a birthday or festival", systemImage: "calendar.badge.plus")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .cardRow()
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .navigationTitle("Lunar")
        .bottomBar {
            Button { isAdding = true } label: { Label("Add event", systemImage: "plus") }
                .buttonStyle(.primary)
        }
        .sheet(isPresented: $isAdding) {
            AddLunarSheet { event, addToCalendar in
                events.append(event)
                if addToCalendar { Task { await export(event) } }
            }
        }
        .sensoryFeedback(.success, trigger: events.count) { old, new in new > old }
        .alert("Calendar", isPresented: Binding(get: { calendarMessage != nil }, set: { if !$0 { calendarMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(calendarMessage ?? "")
        }
    }

    private func export(_ event: LunarEvent) async {
        do {
            let ids = try await LunarCalendarExport.add(event)
            guard let index = events.firstIndex(where: { $0.id == event.id }) else { return }
            events[index].calendarEventIDs = ids
        } catch LunarCalendarExport.Failure.denied {
            calendarMessage = "Calendar access is off — Settings → Privacy & Security → Calendars → Every Time"
        } catch {
            calendarMessage = "Couldn't add to Calendar: \(error.localizedDescription)"
        }
    }
}

private extension View {
    /// List row without chrome, so Cards keep swipe-to-delete.
    func cardRow(vertical: CGFloat = 6) -> some View {
        listRowInsets(EdgeInsets(top: vertical, leading: Theme.padding, bottom: vertical, trailing: Theme.padding))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

private struct TodayCard: View {
    var body: some View {
        let today = Lunar.date(of: .now)
        Card(padding: 20) {
            Text("Today").font(.label).foregroundStyle(.secondary)
            Text(today.chinese)
                .font(.system(size: 52, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline) {
                Text(Lunar.stemBranchYear(of: .now)).font(.cardTitle)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(Date.now, format: .dateTime.weekday(.abbreviated).month().day().year())
                    Text(today.numeric).foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }
        }
    }
}

private struct ConverterCard: View {
    @Binding var date: Date

    var body: some View {
        let lunar = Lunar.date(of: date)
        Card {
            SectionLabel("Convert").padding(.horizontal, -4)
            HStack(spacing: 10) {
                DatePicker("Date", selection: $date, displayedComponents: .date)
                    .labelsHidden()
                Image(systemName: "arrow.right").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(lunar.chinese).font(.system(.title3, design: .rounded, weight: .semibold))
                    Text("\(Lunar.stemBranchYear(of: date)) · \(lunar.numeric)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contentTransition(.numericText())
                .animation(.snappy, value: date)
            }
        }
    }
}

private enum LunarCalendarExport {
    enum Failure: Error { case denied }

    /// Individual all-day events: EKRecurrenceRule can't express lunar recurrence.
    static func add(_ event: LunarEvent) async throws -> [String] {
        let store = EKEventStore()
        guard try await store.requestWriteOnlyAccessToEvents() else { throw Failure.denied }
        let items = Lunar.occurrences(of: event).map { date in
            let item = EKEvent(eventStore: store)
            item.title = "\(event.name) (农历 \(event.lunar.chinese))"
            item.startDate = date
            item.endDate = date
            item.isAllDay = true
            item.calendar = store.defaultCalendarForNewEvents
            return item
        }
        for item in items { try store.save(item, span: .thisEvent, commit: false) }
        try store.commit()
        return items.compactMap(\.eventIdentifier)
    }
}

private struct LunarEventRow: View {
    let event: LunarEvent

    var body: some View {
        let next = Lunar.occurrences(of: event, count: 1).first
        let days = next.map { Lunar.daysUntil($0) }
        Card {
            HStack(alignment: .center, spacing: Theme.spacing) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.name).font(.cardTitle).lineLimit(2)
                    Text("\(event.lunar.numeric) · \(event.repeat.caption)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let next {
                        Text(next, format: .dateTime.month().day().year())
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer(minLength: 0)
                if let days { DayCount(days: days) }
            }
        }
    }
}

private struct DayCount: View {
    let days: Int

    var body: some View {
        if days < 0 {
            Text("Past").font(.label).foregroundStyle(.secondary)
        } else if days == 0 {
            Text("Today 🎉").font(.system(.title3, design: .rounded, weight: .semibold)).foregroundStyle(.tint)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(days)").font(.clock(40))
                Text(days == 1 ? "day" : "days").font(.label).foregroundStyle(.secondary)
            }
        }
    }
}

private struct AddLunarSheet: View {
    let onAdd: (LunarEvent, _ addToCalendar: Bool) -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var nameFocused: Bool
    @State private var name = ""
    @State private var month = Lunar.date(of: .now).month
    @State private var day = Lunar.date(of: .now).day
    @State private var rule = LunarRepeat.yearly
    @State private var addToCalendar = false

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        let next = Lunar.occurrences(month: month, day: day, repeat: rule, count: 1).first
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name, prompt: Text("e.g. Mom's birthday"))
                        .font(.cardTitle)
                        .focused($nameFocused)
                        .submitLabel(.done)
                }
                .listRowBackground(Theme.cardFill)
                Section {
                    HStack(spacing: 0) {
                        Picker("Month", selection: $month) {
                            ForEach(1...12, id: \.self) { m in
                                Text("\(LunarDate(month: m, day: 1).chineseMonth)  \(m)").tag(m)
                            }
                        }
                        Picker("Day", selection: $day) {
                            ForEach(1...30, id: \.self) { d in
                                Text("\(LunarDate(month: 1, day: d).chineseDay)  \(d)").tag(d)
                            }
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    LabeledContent("Next") {
                        if let next {
                            Text(next, format: .dateTime.month().day().year())
                        } else {
                            Text("—")
                        }
                    }
                } header: {
                    Text("Lunar date")
                }
                .listRowBackground(Theme.cardFill)
                Section {
                    Picker("Repeat", selection: $rule) {
                        ForEach(LunarRepeat.allCases, id: \.self) { Text($0.caption).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                } header: {
                    Text("Repeat")
                }
                Section {
                    Toggle(isOn: $addToCalendar) {
                        Label("Add to iPhone Calendar", systemImage: "calendar")
                    }
                } footer: {
                    Text("Adds all-day events to your default calendar.")
                }
                .listRowBackground(Theme.cardFill)
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("New event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .bottomBar {
                Button("Add") {
                    onAdd(LunarEvent(name: trimmedName, month: month, day: day, repeat: rule), addToCalendar)
                    dismiss()
                }
                .buttonStyle(.primary)
                .disabled(trimmedName.isEmpty)
                .opacity(trimmedName.isEmpty ? 0.4 : 1)
            }
            .onAppear { nameFocused = true }
        }
        .presentationDetents([.large])
    }
}

#Preview {
    NavigationStack { LunarCalendarView() }
}
