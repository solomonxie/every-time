import SwiftUI

/// One continuous timeline: each tap marks when something started, tagged with what it was.
struct WhatDidView: View {
    @Stored(ActivityLog.key) private var marks: [ActivityMark] = []
    @Stored(ActivityLog.tagsKey) private var customTags: [String] = []
    @State private var editing: ActivityMark?
    @State private var addsTag = false
    @State private var newTag = ""
    @State private var shownDays = 7

    private var log: ActivityLog { ActivityLog(marks: marks) }
    private var activities: [Activity] { Activity.builtIn + customTags.map { Activity.of($0) } }

    var body: some View {
        TimelineView(.everyMinute) { context in
            let now = context.date
            let spans = log.spans(at: now)
            List {
                Section { hero.whatDidRow() }
                if !spans.isEmpty {
                    Section {
                        today(now: now, spans: spans).whatDidRow()
                    } header: {
                        SectionLabel("Today").textCase(nil)
                    }
                    Section {
                        trends(now: now).whatDidRow()
                    } header: {
                        SectionLabel("Last 7 days").textCase(nil)
                    }
                }
                history(spans: spans)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .animation(.snappy, value: marks)
        .sensoryFeedback(.impact(weight: .medium), trigger: marks.count)
        .navigationTitle("What did I do?")
        .navigationBarTitleDisplayMode(.inline)
        .bottomBar {
            Button { mark(nil) } label: { Label("Mark now", systemImage: "hand.tap.fill") }
                .buttonStyle(.primary)
        }
        .sheet(item: $editing) { mark in
            MarkEditor(mark: mark, activities: activities) { edited in
                marks = marks.map { $0.id == edited.id ? edited : $0 }
            } onDelete: {
                marks.removeAll { $0.id == mark.id }
            }
        }
        .alert("New activity", isPresented: $addsTag) {
            TextField("Name", text: $newTag)
            Button("Add") { addTag() }
            Button("Cancel", role: .cancel) { newTag = "" }
        }
    }

    // MARK: Now

    private var hero: some View {
        let current = log.current
        let activity = Activity.of(current?.tag)
        let tagsCurrent = current != nil && current?.tag == nil
        return VStack(spacing: 18) {
            if let current {
                VStack(spacing: 6) {
                    Label(activity.title, systemImage: activity.symbol)
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .foregroundStyle(tagsCurrent ? .secondary : activity.tint)
                    ElapsedSince(start: current.time)
                    TimerCaption(text: "since \(SleepNow.clock(current.time))")
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { editing = current }
            } else {
                Text("Tap Mark now or an activity whenever you start something. Each one runs until the next.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 24)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text(tagsCurrent ? "What are you doing?" : "Start something now")
                    .font(.label)
                    .foregroundStyle(.secondary)
                FlowLayout(spacing: 8) {
                    ForEach(activities) { item in
                        ActivityChip(activity: item, isOn: item.id == current?.tag) {
                            if tagsCurrent, let current { retag(current, item) } else { mark(item) }
                        }
                        .contextMenu { chipMenu(item) }
                    }
                    Button { addsTag = true } label: {
                        Label("New", systemImage: "plus")
                            .font(.system(.subheadline, design: .rounded))
                            .padding(.horizontal, 12)
                            .frame(minHeight: 36)
                            .overlay(Capsule().strokeBorder(Theme.hairline))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func chipMenu(_ activity: Activity) -> some View {
        ForEach([5, 15, 30, 60], id: \.self) { minutes in
            Button("Started \(minutes) min ago") { mark(activity, at: .now.addingTimeInterval(-Double(minutes) * 60)) }
        }
        if customTags.contains(activity.id) {
            Button("Remove from list", systemImage: "minus.circle", role: .destructive) {
                customTags.removeAll { $0 == activity.id }
            }
        }
    }

    // MARK: Today

    private func today(now: Date, spans: [ActivitySpan]) -> some View {
        let day = log.today(at: now)
        let totals = log.totals(in: day, at: now)
        return Card {
            DayStrip(day: day, spans: spans)
            TotalsList(totals: totals)
        }
    }

    // MARK: Trends

    private func trends(now: Date) -> some View {
        let typical = log.typical(at: now)
        let averages = log.dailyAverages(at: now)
        return Card {
            if typical.nights > 0 {
                HStack(spacing: 10) {
                    stat("Bed", typical.bed.map(clock) ?? "–")
                    stat("Wake", typical.wake.map(clock) ?? "–")
                    stat("Asleep", typical.sleep.map(ActivityLog.duration) ?? "–")
                }
                Text("Average of ^[\(typical.nights) night](inflect: true) marked Sleep, 3 h or longer.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let meals = typical.mealsPerDay {
                Label(String(format: "%.1f meals a day", meals), systemImage: Activity.eat.symbol)
                    .font(.subheadline)
            }
            if !averages.isEmpty {
                Text("Per day").font(.label).foregroundStyle(.secondary)
                TotalsList(totals: averages)
            }
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.label).foregroundStyle(.secondary)
            Text(value).font(.clock(22, weight: .regular)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func clock(_ minutes: Int) -> String {
        SleepNow.clock(Calendar.current.clockTime(minutes: minutes, of: .now))
    }

    // MARK: History

    private func history(spans: [ActivitySpan]) -> some View {
        let byDay = Dictionary(grouping: spans.reversed()) { Calendar.current.startOfDay(for: $0.start) }
        let days = byDay.keys.sorted(by: >)
        return Section {
            if spans.isEmpty {
                Text("Nothing marked yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .whatDidRow()
            }
            ForEach(days.prefix(shownDays), id: \.self) { day in
                Text(day, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                    .font(.label)
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
                    .whatDidRow()
                ForEach(byDay[day] ?? []) { span in
                    Button { editing = marks.first { $0.id == span.id } } label: { SpanRow(span: span) }
                        .buttonStyle(.plain)
                        .whatDidRow()
                        .swipeActions {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                marks.removeAll { $0.id == span.id }
                            }
                        }
                }
            }
            if days.count > shownDays {
                Button("Show older") { shownDays += 14 }
                    .font(.label)
                    .whatDidRow()
            }
        } header: {
            SectionLabel("History").textCase(nil)
        }
    }

    // MARK: Changes

    private func mark(_ activity: Activity?, at time: Date = .now) {
        marks.append(ActivityMark(time: time, tag: activity?.id))
    }

    private func retag(_ mark: ActivityMark, _ activity: Activity) {
        marks = marks.map { $0.id == mark.id ? ActivityMark(id: mark.id, time: mark.time, tag: activity.id) : $0 }
    }

    private func addTag() {
        let name = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        newTag = ""
        guard !name.isEmpty, !activities.contains(where: { $0.id.caseInsensitiveCompare(name) == .orderedSame
            || $0.title.caseInsensitiveCompare(name) == .orderedSame })
        else { return }
        customTags.append(name)
    }
}

/// Live `h:mm:ss` since the current mark; its own view so only the digits redraw each second.
private struct ElapsedSince: View {
    let start: Date

    var body: some View {
        TimelineView(.periodic(from: start, by: 1)) { context in
            let text = TimeText.clock(max(0, Int(context.date.timeIntervalSince(start))))
            Text(text)
                .timerDigits(size: 64)
                .contentTransition(.numericText())
                .animation(.snappy, value: text)
        }
    }
}

struct ActivityChip: View {
    let activity: Activity
    let isOn: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            Label(activity.title, systemImage: activity.symbol)
                .font(.system(.subheadline, design: .rounded, weight: isOn ? .semibold : .regular))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .frame(minHeight: 36)
                .foregroundStyle(isOn ? Color.white : activity.tint)
                .background(isOn ? AnyShapeStyle(activity.tint) : AnyShapeStyle(activity.tint.opacity(0.14)), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// The day's 24 hours as colored stretches.
private struct DayStrip: View {
    let day: DateInterval
    let spans: [ActivitySpan]

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.hairline)
                    ForEach(spans.filter { $0.overlap(with: day) > 0 }) { span in
                        let from = max(span.start, day.start).timeIntervalSince(day.start) / day.duration
                        Rectangle()
                            .fill(span.activity.tint.opacity(span.tag == nil ? 0.35 : 0.85))
                            .frame(width: max(1, geo.size.width * span.overlap(with: day) / day.duration))
                            .offset(x: geo.size.width * from)
                    }
                }
                .clipShape(Capsule())
            }
            .frame(height: 14)
            HStack {
                ForEach(["0", "6", "12", "18", "24"], id: \.self) { hour in
                    Text(hour)
                    if hour != "24" { Spacer() }
                }
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.tertiary)
        }
        .accessibilityHidden(true)
    }
}

private struct TotalsList: View {
    let totals: [ActivityTotal]

    var body: some View {
        let longest = totals.map(\.time).max() ?? 1
        VStack(spacing: 8) {
            ForEach(totals) { total in
                HStack(spacing: 10) {
                    Image(systemName: total.activity.symbol)
                        .foregroundStyle(total.activity.tint)
                        .frame(width: 22)
                    Text(total.activity.title).font(.subheadline)
                    GeometryReader { geo in
                        Capsule()
                            .fill(total.activity.tint.opacity(0.5))
                            .frame(width: max(4, geo.size.width * total.time / longest), height: 6)
                            .frame(maxHeight: .infinity)
                    }
                    Text(ActivityLog.duration(total.time))
                        .font(.label)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 56, alignment: .trailing)
                }
                .frame(minHeight: 22)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

private struct SpanRow: View {
    let span: ActivitySpan

    var body: some View {
        HStack(spacing: 12) {
            Text(SleepNow.clock(span.start))
                .font(.clock(17, weight: .regular))
                .frame(minWidth: 64, alignment: .leading)
            Label(span.activity.title, systemImage: span.activity.symbol)
                .foregroundStyle(span.tag == nil ? .secondary : .primary)
                .labelStyle(TintedIconLabelStyle(tint: span.activity.tint))
            Spacer()
            Text(span.isOpen ? "now" : ActivityLog.duration(span.duration))
                .font(.label)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}

private struct TintedIconLabelStyle: LabelStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.icon.foregroundStyle(tint).frame(width: 22)
            configuration.title
        }
    }
}

/// Change a mark's time or activity, or delete it.
private struct MarkEditor: View {
    @State var mark: ActivityMark
    let activities: [Activity]
    let onSave: (ActivityMark) -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Started", selection: $mark.time, in: ...Date.now)
                Section("Activity") {
                    FlowLayout(spacing: 8) {
                        ForEach(activities + [.untagged]) { item in
                            ActivityChip(activity: item, isOn: item.id == (mark.tag ?? "")) {
                                mark.tag = item.id.isEmpty ? nil : item.id
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section {
                    Button("Delete mark", role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Edit mark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(mark)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

extension View {
    func whatDidRow() -> some View {
        listRowInsets(EdgeInsets(top: 6, leading: Theme.padding, bottom: 6, trailing: Theme.padding))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

#Preview {
    NavigationStack { WhatDidView() }
}
