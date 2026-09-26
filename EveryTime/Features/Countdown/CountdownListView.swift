import SwiftUI

/// Countdowns soonest first, finished ones under Done.
struct CountdownListView: View {
    @Stored(Countdown.storageKey) private var countdowns: [Countdown] = []
    @State private var isAdding = false
    @State private var opened: UUID?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            list(now: context.date)
        }
        .overlay {
            if countdowns.isEmpty {
                ContentUnavailableView(
                    "No countdowns",
                    systemImage: "hourglass",
                    description: Text("Count down to a date and time — with fireworks, sound and a notification when it arrives.")
                )
            }
        }
        .navigationTitle("Countdown")
        .navigationDestination(item: $opened) { CountdownDetailView(id: $0) }
        .bottomBar {
            Button { isAdding = true } label: { Label("New countdown", systemImage: "plus") }
                .buttonStyle(.primary)
        }
        .sheet(isPresented: $isAdding) {
            NavigationStack {
                CountdownEditor(countdown: Countdown(name: "", target: CountdownEditor.wholeMinute(.now.addingTimeInterval(3600))),
                                isNew: true, onSave: add)
            }
        }
        .sensoryFeedback(.success, trigger: countdowns.count) { old, new in new > old }
    }

    private func list(now: Date) -> some View {
        let upcoming = countdowns.filter { !$0.isFinished(at: now) }.sorted { $0.target < $1.target }
        let done = countdowns.filter { $0.isFinished(at: now) }.sorted { $0.target > $1.target }

        return List {
            ForEach(upcoming) { countdown in
                Button { opened = countdown.id } label: { CountdownCard(countdown: countdown, now: now) }
                    .buttonStyle(.plain)
                    .eventRow(vertical: 4)
            }
            .onDelete { delete(upcoming, at: $0) }
            if !done.isEmpty {
                SectionLabel(title: "Done") {
                    Text("\(done.count)").font(.label).foregroundStyle(.tertiary)
                }
                .padding(.top, upcoming.isEmpty ? 0 : 12)
                .eventRow(vertical: 2)
                ForEach(done) { countdown in
                    Button { opened = countdown.id } label: { CountdownCard(countdown: countdown, now: now) }
                        .buttonStyle(.plain)
                        .eventRow(vertical: 4)
                }
                .onDelete { delete(done, at: $0) }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func delete(_ shown: [Countdown], at offsets: IndexSet) {
        let ids = Set(offsets.map { shown[$0].id })
        countdowns.removeAll { ids.contains($0.id) }
        CountdownNotifications.reschedule()
    }

    private func add(_ countdown: Countdown) {
        var countdown = countdown
        countdown.createdAt = .now
        countdowns.append(countdown)
        isAdding = false
        CountdownNotifications.reschedule(requestingAuthorization: countdown.notification)
    }
}

private struct CountdownCard: View {
    let countdown: Countdown
    let now: Date

    var body: some View {
        let finished = countdown.isFinished(at: now)
        let readout = CountdownReadout(remaining: countdown.remaining(at: now))
        Card {
            HStack(alignment: .center, spacing: Theme.spacing) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(countdown.name).font(.cardTitle).lineLimit(2)
                    Group {
                        if finished {
                            Text("Finished \(countdown.target.formatted(.dateTime.month().day().hour().minute()))")
                        } else {
                            Text(countdown.target, format: .dateTime.weekday(.abbreviated).month().day().year().hour().minute())
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if finished {
                    Image(systemName: "checkmark.circle")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(readout.value)")
                                .font(.clock(40))
                                .contentTransition(.numericText(countsDown: true))
                            Text(readout.label).font(.label).foregroundStyle(.secondary)
                        }
                        if !readout.rest.isEmpty {
                            Text(readout.rest).font(.clock(15, weight: .regular)).foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.tint)
                }
            }
        }
        .animation(.snappy, value: readout)
        .contentShape(Rectangle())
        .opacity(finished ? 0.7 : 1)
    }
}

#Preview {
    NavigationStack { CountdownListView() }
}
