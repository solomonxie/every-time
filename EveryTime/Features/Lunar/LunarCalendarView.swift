import EventKit
import SwiftUI

struct LunarCalendarView: View {
    @Stored("calendar.lunar") private var events: [LunarEvent] = []
    @State private var convertDate = Date.now
    @State private var isAdding = false
    @State private var calendarMessage: String?

    var body: some View {
        let today = Lunar.date(of: .now)
        let converted = Lunar.date(of: convertDate)
        List {
            Section("Today") {
                LabeledContent {
                    VStack(alignment: .trailing) {
                        Text("农历 \(today.chinese)")
                        Text(today.numeric).font(.caption)
                    }
                } label: {
                    Text(Date.now, format: .dateTime.month().day().year())
                }
            }
            Section("Convert") {
                DatePicker("Date", selection: $convertDate, displayedComponents: .date)
                LabeledContent("Lunar", value: "\(Lunar.stemBranchYear(of: convertDate)) \(converted.chinese)")
            }
            Section("Events") {
                ForEach(events) { LunarEventRow(event: $0) }
                    .onDelete { events.remove(atOffsets: $0) }
                if events.isEmpty {
                    Text("No events yet").foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Lunar calendar")
        .safeAreaInset(edge: .bottom) {
            Button { isAdding = true } label: {
                Label("Add event", systemImage: "plus").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding()
        }
        .sheet(isPresented: $isAdding) {
            AddLunarSheet { event, addToCalendar in
                events.append(event)
                if addToCalendar { Task { await export(event) } }
            }
        }
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
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading) {
                Text(event.name)
                Text("\(event.lunar.numeric) · \(event.repeat.caption)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let next {
                VStack(alignment: .trailing) {
                    let days = Lunar.daysUntil(next)
                    Text(days < 0 ? "Past" : days == 0 ? "Today 🎉" : "in \(days) days")
                        .monospacedDigit()
                        .foregroundStyle(days < 0 ? .secondary : .primary)
                    Text(next, format: .dateTime.month().day().year())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
                TextField("Name", text: $name).focused($nameFocused)
                Section("Lunar date") {
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
                }
                Section {
                    Picker("Repeat", selection: $rule) {
                        ForEach(LunarRepeat.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.menu)
                    Toggle("Add to iPhone Calendar", isOn: $addToCalendar)
                }
            }
            .navigationTitle("New event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(LunarEvent(name: trimmedName, month: month, day: day, repeat: rule), addToCalendar)
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
            .onAppear { nameFocused = true }
        }
        .presentationDetents([.large])
    }
}

#Preview {
    NavigationStack { LunarCalendarView() }
}
