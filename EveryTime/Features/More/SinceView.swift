import SwiftUI

struct SinceEvent: Identifiable, Codable {
    var id = UUID()
    var name: String
    var date: Date

    func days(to now: Date = .now) -> Int {
        Calendar.current.dateComponents([.day], from: date.startOfDay, to: now.startOfDay).day ?? 0
    }

    func breakdown(to now: Date = .now) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date.startOfDay, to: now.startOfDay)
        let (y, m, d) = (c.year ?? 0, c.month ?? 0, c.day ?? 0)
        return y > 0 ? "\(y) y \(m) mo \(d) d" : "\(m) mo \(d) d"
    }
}

private extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }
}

struct SinceView: View {
    @Stored("calendar.since") private var events: [SinceEvent] = []
    @State private var isAdding = false

    var body: some View {
        List {
            ForEach(events) { event in
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading) {
                        Text(event.name)
                        Text(event.date, format: .dateTime.month().day().year())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("\(event.days()) days").monospacedDigit()
                        Text(event.breakdown())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { events.remove(atOffsets: $0) }
        }
        .overlay {
            if events.isEmpty {
                ContentUnavailableView("No events yet", systemImage: "hourglass", description: Text("Tap + to track one"))
            }
        }
        .navigationTitle("How long since…")
        .toolbar {
            Button("Add", systemImage: "plus") { isAdding = true }
        }
        .sheet(isPresented: $isAdding) {
            AddSinceSheet { events.append($0) }
        }
    }
}

private struct AddSinceSheet: View {
    let onAdd: (SinceEvent) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var date = Date.now

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                DatePicker("Date", selection: $date, in: ...Date.now, displayedComponents: .date)
            }
            .navigationTitle("New event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(SinceEvent(name: name.trimmingCharacters(in: .whitespaces), date: date))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    NavigationStack { SinceView() }
}
