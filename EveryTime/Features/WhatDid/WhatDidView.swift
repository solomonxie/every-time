import SwiftUI

/// One continuous timeline split by pins; each range between pins can be tagged with what it was.
struct WhatDidView: View {
    @Stored(ActivityLog.key) private var marks: [ActivityMark] = []
    @Stored(ActivityLog.tagsKey) private var customTags: [String] = []
    @State private var editing: ActivityMark?
    @State private var held: ActivityMark?
    @State private var addsTag = false
    @State private var newTag = ""
    @State private var showsAllHistory = false
    /// Nil while following now.
    @State private var cursor: Date?
    @State private var selected: UUID?
    @State private var focus: Date?
    @State private var isFullScreen = false
    /// The tile whose Start/End choice is showing, as "section:id".
    @State private var choosing: String?

    private var log: ActivityLog { ActivityLog(marks: marks) }
    @Stored(ActivityLog.orderKey) private var tagOrder: [String] = []

    /// Your drag-and-drop order; tags not placed yet follow in their default order.
    private var activities: [Activity] {
        let all = Activity.builtIn + customTags.map { Activity.of($0) }
        let rank = Dictionary(tagOrder.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
        return all.enumerated()
            .sorted { (rank[$0.element.id] ?? tagOrder.count + $0.offset) < (rank[$1.element.id] ?? tagOrder.count + $1.offset) }
            .map(\.element)
    }

    /// Drops `id` into `target`'s place.
    private func move(_ id: String, to target: String) {
        var ids = activities.map(\.id)
        guard id != target, let from = ids.firstIndex(of: id), let to = ids.firstIndex(of: target) else { return }
        ids.remove(at: from)
        ids.insert(id, at: to)
        withAnimation(.snappy) { tagOrder = ids }
    }

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
                .background {
                    if choosing != nil {
                        Color.clear.contentShape(Rectangle()).onTapGesture { withAnimation(.snappy) { choosing = nil } }
                    }
                }
            }
            .onScrollPhaseChange { _, phase in if phase != .idle { choosing = nil } }
        }
        .onChange(of: cursor) { choosing = nil }
        .onChange(of: selected) { choosing = nil }
        .animation(.snappy, value: marks.count)
        .sensoryFeedback(.impact(weight: .medium), trigger: marks.count)
        .navigationTitle("What did I do?")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Full screen", systemImage: "arrow.up.left.and.arrow.down.right") { isFullScreen = true }
            }
        }
        .fullScreenCover(isPresented: $isFullScreen) {
            FullTimeline(marks: $marks, cursor: $cursor, focus: $focus, activities: activities,
                         selected: selectedSpan, ends: endingRange, record: record) { id in
                isFullScreen = false
                held = marks.first { $0.id == id }
            }
        }
        .sheet(item: $editing) { mark in
            MarkEditor(mark: mark, activities: activities) { edited in
                marks = marks.map { $0.id == edited.id ? edited : $0 }
            } onDelete: {
                marks.removeAll { $0.id == mark.id }
            }
        }
        .confirmationDialog("Pin at \(held.map { SleepNow.clock($0.time) } ?? "")",
                            isPresented: Binding { held != nil } set: { if !$0 { held = nil } },
                            titleVisibility: .visible, presenting: held) { mark in
            Button("Edit") { editing = mark }
            Button("Delete", role: .destructive) { marks.removeAll { $0.id == mark.id } }
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
                Text("Tap a tag when you finish something: the time since your last tap becomes that.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ActivityTimeline(spans: spans, start: window.start, now: now, selected: target?.id,
                             cursor: $cursor, focus: $focus) { id in held = marks.first { $0.id == id } }
                .padding(.horizontal, -Theme.padding)
            VStack(alignment: .leading, spacing: 8) {
                Text(recordHint(spans: spans))
                    .font(.label)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                tagGrid(activities, target: target, section: "all", showsNew: true)
                if let target = selectedSpan {
                    Button("Edit or remove this pin", systemImage: "slider.horizontal.3") { editing = marks.first { $0.id == target.id } }
                        .buttonStyle(.borderless)
                        .font(.label)
                }
            }
        }
        .padding(.vertical, 8)
    }

    /// The range a History tap picked, if any.
    private func target(in spans: [ActivitySpan]) -> ActivitySpan? {
        spans.first { $0.id == selected }
    }

    private var selectedSpan: ActivitySpan? { target(in: log.spans(at: .now)) }

    /// What a tag tap will name.
    private func recordHint(spans: [ActivitySpan]) -> String {
        if let span = target(in: spans) {
            return "Retag \(SleepNow.clock(span.start)) – \(span.isOpen ? "now" : SleepNow.clock(span.end))"
        }
        return "Tap a tag, then Start or End at \(SleepNow.clock(ActivityLog.rounded(cursor ?? .now)))"
    }

    /// The range an End tap would name: last pin up to the cursor or now.
    private var endingRange: (start: Date, end: Date)? {
        let end = ActivityLog.rounded(cursor ?? .now)
        return log.spans(at: .now).last { $0.start < end }.map { ($0.start, end) }
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
            Button("Started \(minutes) min ago") { marks.append(ActivityMark(time: ActivityLog.rounded(.now.addingTimeInterval(-Double(minutes) * 60)), tag: activity.id)) }
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

    /// Plain rows, not a lazy grid: the Start/End card overlaps neighbours and needs zIndex to sit on top.
    private func tagGrid(_ items: [Activity], target: ActivitySpan?, section: String, showsNew: Bool = false) -> some View {
        let cells: [Activity?] = items + (showsNew ? [nil] : [])
        let rows = stride(from: 0, to: cells.count, by: 4).map { Array(cells[$0..<min($0 + 4, cells.count)]) }
        return VStack(spacing: 8) {
            ForEach(rows.indices, id: \.self) { r in
                let isChoosing = rows[r].contains { $0.map { choosing == "\(section):\($0.id)" } ?? false }
                HStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { column in
                        if column < rows[r].count, let item = rows[r][column] {
                            tagCell(item, column: column, target: target, section: section)
                        } else if column < rows[r].count {
                            newTagTile
                        } else {
                            Color.clear.frame(maxWidth: .infinity, minHeight: 58)
                        }
                    }
                }
                .zIndex(isChoosing ? 1 : 0)
            }
        }
    }

    private func tagCell(_ item: Activity, column: Int, target: ActivitySpan?, section: String) -> some View {
        let key = "\(section):\(item.id)"
        return TagTile(activity: item, isOn: item.id == target?.tag || choosing == key) {
            if target != nil { record(item, starts: false) } else { withAnimation(.snappy) { choosing = choosing == key ? nil : key } }
        }
        .contextMenu { chipMenu(item) }
        .draggable(item.id) { TagTile(activity: item, isOn: true) {}.frame(width: 80) }
        .dropDestination(for: String.self) { ids, _ in
            guard let id = ids.first else { return false }
            move(id, to: item.id)
            return true
        }
        // Floats above the tile, kept on screen at the row's edges; a popover sometimes opened as a sheet.
        .overlay(alignment: column == 0 ? .topLeading : column == 3 ? .topTrailing : .top) {
            if choosing == key {
                StartEndChoice(activity: item, ends: endingRange, at: ActivityLog.rounded(cursor ?? .now)) { starts in
                    choosing = nil
                    record(item, starts: starts)
                }
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
                .fixedSize()
                .alignmentGuide(.top) { $0[.bottom] + 6 }
                .transition(.scale(scale: 0.8, anchor: .bottom).combined(with: .opacity))
            }
        }
        .zIndex(choosing == key ? 1 : 0)
    }

    private var newTagTile: some View {
        Button { addsTag = true } label: {
            VStack(spacing: 4) {
                Image(systemName: "plus").font(.title3)
                Text("New").font(.caption2)
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 58)
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.hairline))
        }
        .buttonStyle(.plain)
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
                    if selected == span.id {
                        selected = nil
                        cursor = nil
                    } else {
                        selected = span.id
                        focus = span.start.addingTimeInterval(span.duration / 2)
                    }
                } label: { SpanRow(span: span, isOn: span.id == target(in: spans)?.id) }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Edit", systemImage: "slider.horizontal.3") { editing = marks.first { $0.id == span.id } }
                        Button("Delete", systemImage: "trash", role: .destructive) { marks.removeAll { $0.id == span.id } }
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

    /// One tap: retags a picked range; otherwise pins `cursor` or now and tags the range it starts or ends.
    /// A pin at the same time is reused, so a wrong tap is fixed by tapping the right tag.
    private func record(_ activity: Activity, starts: Bool) {
        let spans = log.spans(at: .now)
        if let span = target(in: spans) {
            setTag(span.id, activity.id)
            selected = nil
            return
        }
        let time = ActivityLog.rounded(cursor ?? .now)
        let near = marks.first { abs($0.time.timeIntervalSince(time)) < 120 }
        if starts {
            if let near { setTag(near.id, activity.id) } else { marks.append(ActivityMark(time: time, tag: activity.id)) }
            return
        }
        guard let ending = spans.last(where: { $0.start < time }) else {
            marks.append(ActivityMark(time: time, tag: activity.id))
            return
        }
        if let near, let before = spans.last(where: { $0.start < near.time }) {
            setTag(before.id, activity.id)
        } else {
            marks.append(ActivityMark(time: time, tag: nil))
            setTag(ending.id, activity.id)
        }
    }

    private func setTag(_ id: UUID, _ tag: String?) {
        marks = marks.map { $0.id == id ? ActivityMark(id: id, time: $0.time, tag: tag) : $0 }
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

/// The timeline alone, zoomable, to see whole days at once.
private struct FullTimeline: View {
    @Binding var marks: [ActivityMark]
    @Binding var cursor: Date?
    @Binding var focus: Date?
    let activities: [Activity]
    let selected: ActivitySpan?
    let ends: (start: Date, end: Date)?
    let record: (Activity, Bool) -> Void
    @State private var open: String?
    let onHoldPin: (UUID) -> Void
    @State private var hourWidth: CGFloat = 40

    private static let zoom: [CGFloat] = [10, 20, 40, 80, 120]

    var body: some View {
        SidewaysScreen(horizontalPadding: 36) {
            TimelineView(.everyMinute) { context in
                let now = max(context.date, .now)
                let spans = ActivityLog(marks: marks).spans(at: now)
                let start = Calendar.current.date(byAdding: .day, value: -14, to: Calendar.current.startOfDay(for: now)) ?? now
                VStack(alignment: .leading, spacing: 12) {
                    header
                    Spacer(minLength: 0)
                    ActivityTimeline(spans: spans, start: start, now: now, selected: selected?.id,
                                     cursor: $cursor, focus: $focus, hourWidth: hourWidth, onHoldPin: onHoldPin)
                    Spacer(minLength: 0)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(activities) { item in
                                ActivityChip(activity: item, isOn: item.id == selected?.tag || item.id == open) {
                                    if selected != nil { record(item, false) } else { withAnimation(.snappy) { open = open == item.id ? nil : item.id } }
                                }
                                if open == item.id {
                                    StartEndChoice(activity: item, ends: ends, at: ActivityLog.rounded(cursor ?? .now), isCompact: true) { starts in
                                        open = nil
                                        record(item, starts)
                                    }
                                    .transition(.scale.combined(with: .opacity))
                                }
                            }
                        }
                    }
                }
            }
        }
        .gesture(MagnifyGesture().onEnded { value in step(value.magnification > 1 ? 1 : -1) })
        .sensoryFeedback(.selection, trigger: hourWidth)
    }

    private var header: some View {
        HStack(spacing: 14) {
            SidewaysCloseButton()
            Text(cursor.map { $0.formatted(.dateTime.weekday(.abbreviated).hour().minute()) } ?? "Now")
                .font(.clock(28))
                .monospacedDigit()
                .contentTransition(.numericText())
            Spacer()
            Group {
                Button("Zoom out", systemImage: "minus.magnifyingglass") { step(-1) }
                    .disabled(hourWidth == Self.zoom.first)
                Button("Zoom in", systemImage: "plus.magnifyingglass") { step(1) }
                    .disabled(hourWidth == Self.zoom.last)
            }
            .labelStyle(.iconOnly)
            .font(.title3)
            if cursor != nil {
                Button("Now") { cursor = nil }
                    .buttonStyle(.soft)
                    .fixedSize()
            }
        }
    }

    private func step(_ by: Int) {
        guard let i = Self.zoom.firstIndex(of: hourWidth) else { return }
        withAnimation(.snappy) { hourWidth = Self.zoom[min(Self.zoom.count - 1, max(0, i + by))] }
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

/// Same-size square per tag: icon over name, so tags line up in a grid.
struct TagTile: View {
    let activity: Activity
    let isOn: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            VStack(spacing: 4) {
                Image(systemName: activity.symbol).font(.title3)
                Text(activity.title).font(.caption2.weight(isOn ? .semibold : .regular)).lineLimit(1).minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, minHeight: 58)
            .foregroundStyle(isOn ? Color.white : activity.tint)
            .background(isOn ? AnyShapeStyle(activity.tint) : AnyShapeStyle(activity.tint.opacity(0.12)),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(activity.title)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// After tapping a tag: did it start now, or end now (naming the range since the last pin)?
struct StartEndChoice: View {
    let activity: Activity
    let ends: (start: Date, end: Date)?
    let at: Date
    var isCompact = false
    let pick: (Bool) -> Void

    var body: some View {
        HStack(spacing: 8) {
            option("Start", "play.fill", detail: "from \(SleepNow.clock(at))", starts: true)
            if let ends {
                option("End", "stop.fill", detail: "\(SleepNow.clock(ends.start))–\(SleepNow.clock(ends.end))", starts: false)
            }
        }
        .padding(isCompact ? 0 : 8)
    }

    private func option(_ title: String, _ symbol: String, detail: String, starts: Bool) -> some View {
        Button { pick(starts) } label: {
            VStack(spacing: 2) {
                Label(title, systemImage: symbol).font(.subheadline.weight(.semibold))
                if !isCompact { Text(detail).font(.caption2.monospacedDigit()).opacity(0.8) }
            }
            .padding(.horizontal, 14)
            .frame(minWidth: isCompact ? 70 : 96, minHeight: isCompact ? 36 : 54)
            .foregroundStyle(starts ? Color.white : Color(.systemBackground))
            .background(starts ? activity.tint : Color.primary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
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
                        onSave(ActivityMark(id: mark.id, time: ActivityLog.rounded(mark.time), tag: mark.tag))
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
