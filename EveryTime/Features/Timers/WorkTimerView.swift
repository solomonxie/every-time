import SwiftUI

/// Today's worked time, clock in/out and break buttons, and a per-day history exportable as CSV.
struct WorkTimerView: View {
    @Stored(WorkLog.key) private var spans: [WorkSpan] = []

    private var log: WorkLog { WorkLog(spans: spans) }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let days = log.days(at: context.date)
            List {
                Section {
                    hero
                        .listRowInsets(EdgeInsets(top: 8, leading: Theme.padding, bottom: 28, trailing: Theme.padding))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                Section {
                    if days.isEmpty {
                        Text("No work logged yet — clock in to start today")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .historyRow()
                    }
                    ForEach(days) { WorkDayRow(day: $0).historyRow() }
                        .onDelete { offsets in
                            update { log in offsets.forEach { log.deleteDay(days[$0].date) } }
                        }
                } header: {
                    SectionLabel("History").textCase(nil)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .animation(.snappy, value: spans)
        .sensoryFeedback(.impact(weight: .medium), trigger: spans.count)
        .navigationTitle(AppTool.work.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: CSVFile(text: log.csv()), preview: SharePreview("Work hours.csv")) {
                    Label("Export CSV", systemImage: "square.and.arrow.up")
                }
                .disabled(spans.isEmpty)
            }
        }
    }

    private var hero: some View {
        let state = log.state
        return VStack(spacing: 20) {
            TimelineView(.animation(minimumInterval: 1, paused: state == .off)) { context in
                let today = log.today(at: context.date)
                VStack(spacing: 6) {
                    TimerCaption(text: "Today")
                    let text = TimeText.clock(Int(today?.worked ?? 0))
                    Text(text)
                        .timerDigits()
                        .contentTransition(.numericText())
                        .animation(.snappy, value: text)
                    TimerCaption(text: caption(state, today: today), tint: state == .onBreak ? Theme.Tone.warn : nil)
                }
            }
            .padding(.vertical, 12)
            controls(state)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func controls(_ state: WorkLog.State) -> some View {
        HStack(spacing: 20) {
            switch state {
            case .off:
                Button("Clock in") { update { $0.clockIn() } }
                    .buttonStyle(RoundButtonStyle(size: 96, tint: .accentColor))
            case .working:
                Button("Break") { update { $0.startBreak() } }
                    .buttonStyle(RoundButtonStyle(size: 84, tint: Theme.Tone.warn))
                Spacer()
                Button("Clock out") { update { $0.clockOut() } }
                    .buttonStyle(RoundButtonStyle(size: 84, tint: Theme.Tone.bad))
            case .onBreak:
                Button("Back") { update { $0.clockIn() } }
                    .buttonStyle(RoundButtonStyle(size: 84, tint: .accentColor))
                Spacer()
                Button("Clock out") { update { $0.clockOut() } }
                    .buttonStyle(RoundButtonStyle(size: 84, tint: Theme.Tone.bad))
            }
        }
        .animation(.snappy, value: state)
    }

    private func caption(_ state: WorkLog.State, today: WorkDay?) -> String {
        let since = log.openSince?.formatted(date: .omitted, time: .shortened) ?? ""
        let rested = (today?.rested ?? 0) > 0 ? " · break \(WorkLog.hoursMinutes(today?.rested ?? 0))" : ""
        switch state {
        case .working: return "Working since \(since)" + rested
        case .onBreak: return "On break since \(since)" + rested
        case .off: return today == nil ? "Not clocked in" : "Clocked out" + rested
        }
    }

    private func update(_ change: (inout WorkLog) -> Void) {
        var log = log
        change(&log)
        spans = log.spans
    }
}

private struct WorkDayRow: View {
    let day: WorkDay

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(day.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                    .font(.system(.body, design: .rounded))
                HStack(spacing: 6) {
                    Text(day.firstIn, format: .dateTime.hour().minute())
                    Text("–")
                    if day.isOpen { Text("now") } else { Text(day.lastOut, format: .dateTime.hour().minute()) }
                    if day.rested > 0 {
                        Text("·")
                        Text("break \(WorkLog.hoursMinutes(day.rested))")
                    }
                }
                .font(.label)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Text(WorkLog.hoursMinutes(day.worked))
                .font(.clock(20, weight: .regular))
        }
    }
}

private extension View {
    func historyRow() -> some View {
        listRowInsets(EdgeInsets(top: 10, leading: Theme.padding, bottom: 10, trailing: Theme.padding))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

#Preview {
    NavigationStack { WorkTimerView() }
}
