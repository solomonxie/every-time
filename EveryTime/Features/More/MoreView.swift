import SwiftUI

/// Every tool one tap away, then the tab bar editor and settings, inline.
struct MoreView: View {
    @Environment(TimerStore.self) private var timers
    @Stored("app.tabs") private var pinned = AppTool.defaultPins.map(\.rawValue)
    @Stored(TimerStore.interviewMinutesKey) private var interviewMinutes = TimerStore.defaultInterviewMinutes
    @Stored(TimerStore.rehearsalMinutesKey) private var rehearsalMinutes = TimerStore.defaultRehearsalMinutes
    @Stored(TimerStore.leetcodeHistoryKey) private var history: [TimerSession] = []
    @Stored(WorkLog.key) private var workSpans: [WorkSpan] = []

    private var pins: [AppTool] { AppTool.pins(from: pinned) }

    var body: some View {
        NavigationStack {
            List {
                Text("More")
                    .font(.screenTitle)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 0, trailing: 4))

                ForEach(AppTool.Group.allCases) { group in
                    Section {
                        ForEach(group.tools) { toolRow($0) }
                    } header: {
                        SectionLabel(group.rawValue).textCase(nil)
                    }
                    .listRowBackground(Theme.cardFill)
                }

                tabBarSection

                SettingsSections()
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .listSectionSpacing(Theme.spacing * 2)
            .navigationTitle("More")
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: AppTool.self) { $0.destination }
        }
    }

    // MARK: Tools

    private func toolRow(_ tool: AppTool) -> some View {
        NavigationLink(value: tool) {
            HStack(spacing: Theme.spacing) {
                Image(systemName: tool.symbol)
                    .foregroundStyle(.secondary)
                    .frame(width: 28)
                Text(tool.title)
                if pins.contains(tool) {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .accessibilityLabel("Pinned")
                }
                Spacer(minLength: 8)
                liveValue(tool)
                    .font(.clock(17, weight: .regular))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            .frame(minHeight: 44)
        }
        .contextMenu { pinButton(tool) }
        .swipeActions(edge: .trailing) { pinButton(tool).tint(.accentColor) }
    }

    @ViewBuilder
    private func liveValue(_ tool: AppTool) -> some View {
        switch tool {
        case .stopwatch:
            if timers.stopwatch.clock.hasTime {
                ClockTimeline(clock: timers.stopwatch.clock, interval: 1) { Text(TimeText.clock(Int($0))) }
            }
        case .interview:
            countdown(timers.interview, minutes: interviewMinutes, allowsOvertime: false)
        case .rehearsal:
            countdown(timers.rehearsal, minutes: rehearsalMinutes, allowsOvertime: true)
        case .leetcode:
            Text("^[\(history.count) session](inflect: true)").font(.subheadline)
        case .work:
            let log = WorkLog(spans: workSpans)
            if !workSpans.isEmpty {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(TimeText.clock(Int(log.today(at: context.date)?.worked ?? 0)))
                }
            }
        default:
            EmptyView()
        }
    }

    private func countdown(_ clock: ElapsedClock, minutes: Int, allowsOvertime: Bool) -> some View {
        ClockTimeline(clock: clock, interval: 1) { elapsed in
            let remaining = TimeInterval(minutes * 60) - elapsed
            Text(TimeText.countdown(allowsOvertime ? remaining : max(0, remaining)))
        }
    }

    // MARK: Tab bar

    private var tabBarSection: some View {
        Section {
            ForEach(pins) { tool in
                HStack(spacing: Theme.spacing) {
                    Image(systemName: tool.symbol)
                        .foregroundStyle(.secondary)
                        .frame(width: 28)
                    Text(tool.title)
                    Spacer(minLength: 8)
                    Button { unpin(tool) } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(pins.count > 1 ? Theme.Tone.bad : Color.secondary.opacity(0.4))
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .disabled(pins.count <= 1)
                    .accessibilityLabel("Unpin \(tool.title)")
                    Image(systemName: "line.3.horizontal")
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
            .onMove { from, to in
                var tools = pins
                tools.move(fromOffsets: from, toOffset: to)
                save(tools)
            }

            Menu {
                ForEach(AppTool.Group.allCases) { group in
                    Section(group.rawValue) {
                        ForEach(group.tools.filter { !pins.contains($0) }) { tool in
                            Button { pin(tool) } label: { Label(tool.title, systemImage: tool.symbol) }
                        }
                    }
                }
            } label: {
                Label("Add a tool", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .disabled(pins.count >= AppTool.maxPins)
        } header: {
            SectionLabel(title: "Tab bar") {
                Text("\(pins.count) of \(AppTool.maxPins)").font(.label).foregroundStyle(.tertiary)
            }
            .textCase(nil)
        } footer: {
            Text(pins.count >= AppTool.maxPins
                 ? "Up to \(AppTool.maxPins). Remove one to add another. Hold and drag to reorder."
                 : "Up to \(AppTool.maxPins), shown before More. Hold and drag to reorder.")
        }
        .listRowBackground(Theme.cardFill)
    }

    @ViewBuilder
    private func pinButton(_ tool: AppTool) -> some View {
        if pins.contains(tool) {
            Button { unpin(tool) } label: { Label("Unpin from tab bar", systemImage: "pin.slash") }
                .disabled(pins.count <= 1)
        } else {
            Button { pin(tool) } label: { Label("Pin to tab bar", systemImage: "pin") }
                .disabled(pins.count >= AppTool.maxPins)
        }
    }

    private func pin(_ tool: AppTool) {
        guard pins.count < AppTool.maxPins, !pins.contains(tool) else { return }
        save(pins + [tool])
    }

    private func unpin(_ tool: AppTool) {
        guard pins.count > 1 else { return }
        save(pins.filter { $0 != tool })
    }

    private func save(_ tools: [AppTool]) {
        withAnimation(.snappy) { pinned = tools.map(\.rawValue) }
    }
}

#Preview {
    MoreView()
        .environment(TimerStore())
}
