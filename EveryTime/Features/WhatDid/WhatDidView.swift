import SwiftUI

/// One continuous timeline split by pins; each range between pins can be tagged with what it was.
struct WhatDidView: View {
    @Stored(ActivityLog.key) private var marks: [ActivityMark] = []
    @Stored(ActivityLog.tagsKey) private var customTags: [String] = []
    @State private var editing: ActivityMark?
    @State private var addsTag = false
    @State private var newTag = ""
    @State private var showsAllHistory = false
    /// Nil while following now.
    @State private var cursor: Date?
    @State private var selected: UUID?
    @State private var focus: Date?

    private var log: ActivityLog { ActivityLog(marks: marks) }
    private var activities: [Activity] { Activity.builtIn + customTags.map { Activity.of($0) } }

    var body: some View {
        TimelineView(.everyMinute) { context in
            // The minute tick only triggers redraws; a pin just added may be newer than it.
            let now = max(context.date, .now)
            // Stored decodes on every read; read once per redraw.
            let log = log
            let spans = log.spans(at: now)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                Section { hero(now: now, spans: spans).whatDidRow() }
                history(spans: spans)
                if !spans.isEmpty {
                    Section {
                        today(now: now, spans: spans).whatDidRow()
                    } header: {
                        SectionLabel("Today").textCase(nil).padding(.horizontal, Theme.padding).padding(.top, 14)
                    }
                    Section {
                        trends(now: now).whatDidRow()
                    } header: {
                        SectionLabel("Last 7 days").textCase(nil).padding(.horizontal, Theme.padding).padding(.top, 14)
                    }
                }
                }
                .padding(.vertical, 8)
            }
        }
        .animation(.snappy, value: marks.count)
        .sensoryFeedback(.impact(weight: .medium), trigger: marks.count)
        .navigationTitle("What did I do?")
        .navigationBarTitleDisplayMode(.inline)
        .bottomBar {
            HStack(spacing: Theme.spacing) {
                if cursor != nil {
                    Button("Now") { cursor = nil }
                        .buttonStyle(.soft)
                        .frame(maxWidth: 96)
                }
                Button { split(at: cursor ?? .now) } label: {
                    Label(cursor.map { "Mark at \(SleepNow.clock($0))" } ?? "Mark now", systemImage: "hand.tap.fill")
                }
                .buttonStyle(.primary)
            }
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

    /// Live "since" for the open range, the timeline, then tags for the selected range.
    private func hero(now: Date, spans: [ActivitySpan]) -> some View {
        let target = target(in: spans)
        let window = window(now: now, spans: spans)
        return VStack(alignment: .leading, spacing: 12) {
            if let open = spans.last {
                HStack(spacing: 8) {
                    Image(systemName: open.activity.symbol).foregroundStyle(open.activity.tint)
                    Text(open.tag == nil ? "Since \(SleepNow.clock(open.start))" : "\(open.activity.title) since \(SleepNow.clock(open.start))")
                    Spacer()
                    ElapsedSince(start: open.start)
                }
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
            } else {
                Text("Tap Mark now to start splitting your day. Tap the timeline anywhere to add a pin there; tap a History row to tag it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ActivityTimeline(spans: spans, start: window.start, now: now, selected: target?.id,
                             cursor: $cursor, focus: $focus) { split(at: $0) }
                .padding(.horizontal, -Theme.padding)
            VStack(alignment: .leading, spacing: 8) {
                if let target {
                    Text("\(SleepNow.clock(target.start)) – \(target.isOpen ? "now" : SleepNow.clock(target.end)) · \(ActivityLog.duration(target.duration))")
                        .font(.label)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                FlowLayout(spacing: 8) {
                    ForEach(activities) { item in
                        ActivityChip(activity: item, isOn: target != nil && item.id == target?.tag) {
                            if let target { tag(target, item) }
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
                .disabled(target == nil)
                if let target {
                    Button("Edit or remove this pin", systemImage: "slider.horizontal.3") { editing = marks.first { $0.id == target.id } }
                        .buttonStyle(.borderless)
                        .font(.label)
                }
            }
        }
        .padding(.vertical, 8)
    }

    /// The tapped range, else the last closed one (the one Mark just made), else the open one.
    private func target(in spans: [ActivitySpan]) -> ActivitySpan? {
        spans.first { $0.id == selected } ?? (spans.count > 1 ? spans[spans.count - 2] : spans.last)
    }

    /// Whole days from the first pin (at most two weeks back) through today.
    private func window(now: Date, spans: [ActivitySpan]) -> (start: Date, days: Int) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let earliest = calendar.date(byAdding: .day, value: -14, to: today) ?? today
        let first = spans.first.map { calendar.startOfDay(for: $0.start) } ?? today
        let start = max(earliest, min(first, today))
        return (start, (calendar.dateComponents([.day], from: start, to: today).day ?? 0) + 1)
    }

    @ViewBuilder
    private func chipMenu(_ activity: Activity) -> some View {
        ForEach([5, 15, 30, 60], id: \.self) { minutes in
            Button("Started \(minutes) min ago") { marks.append(ActivityMark(time: .now.addingTimeInterval(-Double(minutes) * 60), tag: activity.id)) }
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
        let recent = Array(spans.reversed())
        return Section {
            if spans.isEmpty {
                Text("Nothing marked yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .whatDidRow()
            }
            ForEach(showsAllHistory ? recent : Array(recent.prefix(Self.foldedHistory))) { span in
                Button {
                    selected = span.id
                    focus = span.start.addingTimeInterval(span.duration / 2)
                } label: { SpanRow(span: span, isOn: span.id == target(in: spans)?.id) }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Edit pin", systemImage: "slider.horizontal.3") { editing = marks.first { $0.id == span.id } }
                    }
                    .whatDidRow()
            }
            if recent.count > Self.foldedHistory {
                Button(showsAllHistory ? "Show less" : "Show all \(recent.count)") { showsAllHistory.toggle() }
                    .font(.label)
                    .whatDidRow()
            }
        } header: {
            SectionLabel("History").textCase(nil).padding(.horizontal, Theme.padding).padding(.top, 14)
        }
    }

    private static let foldedHistory = 3

    // MARK: Changes

    /// A new pin at `time`; the range it closes becomes the one the tags apply to.
    private func split(at time: Date) {
        let before = log.spans(at: .now).last { $0.start < time }
        marks.append(ActivityMark(time: time, tag: nil))
        selected = before?.id
    }

    /// Tapping the range's own tag clears it.
    private func tag(_ span: ActivitySpan, _ activity: Activity) {
        let tag = span.tag == activity.id ? nil : activity.id
        marks = marks.map { $0.id == span.id ? ActivityMark(id: span.id, time: $0.time, tag: tag) : $0 }
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

/// Live `h:mm:ss` since the last pin; its own view so only the digits redraw each second.
private struct ElapsedSince: View {
    let start: Date

    var body: some View {
        TimelineView(.periodic(from: start, by: 1)) { context in
            let text = TimeText.clock(max(0, Int(context.date.timeIntervalSince(start))))
            Text(text)
                .font(.clock(17, weight: .medium))
                .foregroundStyle(.secondary)
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
    let isOn: Bool

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
        .padding(.horizontal, 8)
        .frame(minHeight: 40)
        .background(isOn ? Color.accentColor.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 10))
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
    @State private var confirmsDelete = false

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
                    Button("Remove pin", role: .destructive) { confirmsDelete = true }
                        .confirmationDialog("Remove this pin? Its range joins the one before.", isPresented: $confirmsDelete,
                                            titleVisibility: .visible) {
                            Button("Remove pin", role: .destructive) {
                                onDelete()
                                dismiss()
                            }
                        }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Edit pin")
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
        padding(.horizontal, Theme.padding).padding(.vertical, 6)
    }
}

#Preview {
    NavigationStack { WhatDidView() }
}
