import SwiftUI

/// Name, date, type and reminder for a new or existing important event.
struct ImportantEventEditor: View {
    let isNew: Bool
    let onSave: (ImportantEvent) -> Void
    @State private var event: ImportantEvent
    @Environment(\.dismiss) private var dismiss
    @FocusState private var nameFocused: Bool

    init(event: ImportantEvent, isNew: Bool, onSave: @escaping (ImportantEvent) -> Void) {
        _event = State(initialValue: event)
        self.isNew = isNew
        self.onSave = onSave
    }

    private var trimmedName: String { event.name.trimmingCharacters(in: .whitespaces) }
    private var fromCalendar: String? {
        if case .calendar(_, let title) = event.source { return title }
        return nil
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $event.name, prompt: Text("e.g. Alex & Sam"))
                    .font(.cardTitle)
                    .focused($nameFocused)
                    .submitLabel(.done)
            } footer: {
                if let fromCalendar { Label("From Calendar: \(fromCalendar)", systemImage: "calendar") }
            }
            .listRowBackground(Theme.cardFill)
            Section {
                DatePicker("Date", selection: $event.date,
                           displayedComponents: event.hasTime ? [.date, .hourAndMinute] : .date)
                Toggle(isOn: $event.hasTime.animation(.snappy)) { Label("Time", systemImage: "clock") }
                Picker("Type", selection: $event.type) {
                    ForEach(EventType.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
                }
            }
            .listRowBackground(Theme.cardFill)
            Section {
                Toggle(isOn: $event.notify) { Label("Remind me", systemImage: "bell") }
            } footer: {
                Text(event.isFuture(at: .now)
                     ? "A notification when it arrives\(event.hasTime ? "" : " (9:00 AM)"), then on each anniversary."
                     : "A notification at 9:00 AM on each anniversary.")
            }
            .listRowBackground(Theme.cardFill)
        }
        .scrollContentBackground(.hidden)
        .navigationTitle(isNew ? "New event" : "Edit event")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !(isNew && fromCalendar != nil) {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .bottomBar {
            Button(isNew ? "Add" : "Save") {
                event.name = trimmedName
                onSave(event)
            }
            .buttonStyle(.primary)
            .disabled(trimmedName.isEmpty)
            .opacity(trimmedName.isEmpty ? 0.4 : 1)
        }
        .onAppear { if isNew && event.name.isEmpty { nameFocused = true } }
    }
}
