import SwiftUI

/// One continuous timeline split by pins; each range between pins can be tagged with what it was.
struct WhatDidView: View {
    @Stored(ActivityLog.key) private var marks: [ActivityMark] = []
    @Stored(ActivityLog.tagsKey) private var customTags: [String] = []
    @Stored(ActivityLog.stylesKey) private var tagStyles: [String: TagStyle] = [:]
    @State private var editing: ActivityMark?
    @State private var held: ActivityMark?
    /// The custom tag being made or restyled; "" = new.
    @State private var tagEditor: TagTarget?
    @State private var expandedDays: Set<Date> = []

    private struct TagTarget: Identifiable { let id: String }
    /// Nil while following now.
    @State private var cursor: Date?
    @State private var selected: UUID?
    @State private var focus: Date?
    /// The tile whose Start/End choice is showing, as "section:id".
    @State private var choosing: String?

    private var log: ActivityLog { ActivityLog(marks: marks) }
    @Stored(ActivityLog.orderKey) private var tagOrder: [String] = []
    @Stored(JetLagKey.profile) private var profile: JetLagProfile? = nil

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
            let moments = log.moments(at: now)
            let planned = log.planned(at: now)
            let due = log.dueRepeats(at: now)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                Section { hero(now: now, spans: spans, moments: moments, planned: planned).whatDidRow() }
                activities(spans: spans, moments: moments, planned: planned)
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
                // A tap on empty space closes the Start/End card and puts the cursor back on now.
                .background {
                    Color.clear.contentShape(Rectangle()).onTapGesture {
                        withAnimation(.snappy) {
                            choosing = nil
                            cursor = nil
                        }
                    }
                }
            }
            .onScrollPhaseChange { _, phase in if phase != .idle { choosing = nil } }
            // A daily pin whose time has come becomes a real pin.
            .task(id: now) { if !due.isEmpty { marks += due } }
        }
        .onChange(of: cursor) { choosing = nil }
        .onChange(of: selected) { choosing = nil }
        .onChange(of: marks) { Task { await ActivityAlarms.sync(marks) } }
        .task { await ActivityAlarms.sync(marks) }
        .animation(.snappy, value: marks.count)
        .sensoryFeedback(.impact(weight: .medium), trigger: marks.count)
        .navigationTitle("What did I do?")
        .navigationBarTitleDisplayMode(.inline)
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
        .sheet(item: $tagEditor) { target in
            let id = target.id
            TagEditor(name: id, style: tagStyles[id] ?? TagStyle(), taken: activities.map(\.id) + activities.map(\.title)) { name, style, _ in
                if id.isEmpty { customTags.append(name) }
                tagStyles[name] = style
                Activity.customStyles = tagStyles
            }
        }
        .onAppear {
            Activity.customStyles = tagStyles
            if marks.contains(where: { ActivityLog.oldTags.contains($0.tag ?? "") }) { marks = ActivityLog.migrateTags(marks) }
        }
    }

    // MARK: Now

    /// Live "since" for the open range, the ring, then tags for the selected range.
    private func hero(now: Date, spans: [ActivitySpan], moments: [ActivityMark], planned: [ActivitySpan]) -> some View {
        let target = target(in: spans)
        let window = window(now: now, spans: spans)
        return VStack(alignment: .leading, spacing: 12) {
            if let open = spans.last, open.isOpen {
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
            ActivityRing(spans: spans, moments: moments, planned: planned, start: window.start, now: now, selected: target?.id, noCoffee: noCoffee(now: now),
                         cursor: $cursor, focus: $focus) { id in held = marks.first { $0.id == id } }
                .frame(maxWidth: 300)
                .frame(maxWidth: .infinity)
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

    /// Tonight's coffee cutoff to bedtime, from the usual hours.
    private func noCoffee(now: Date) -> DateInterval {
        let bed = NapAdvice(profile: profile ?? JetLagProfile()).current(at: now).bed
        return DateInterval(start: Caffeine.cutoff(bed: bed), end: bed)
    }

    /// The range an Activities tap picked, if any.
    private func target(in spans: [ActivitySpan]) -> ActivitySpan? {
        spans.first { $0.id == selected }
    }

    private var selectedSpan: ActivitySpan? { target(in: log.spans(at: .now) + log.planned(at: .now)) }

    /// The cursor is ahead of now: a tag becomes a plan.
    private var isPlanning: Bool { cursor.map { $0 > .now } ?? false }

    /// What a tag tap will name.
    private func recordHint(spans: [ActivitySpan]) -> String {
        if let span = target(in: spans) {
            return "Retag \(SleepNow.clock(span.start)) – \(span.isOpen ? "now" : SleepNow.clock(span.end))"
        }
        if let cursor, cursor > .now { return "Tap a tag to plan it for \(SleepNow.clock(ActivityLog.rounded(cursor)))" }
        return "Tap a tag: it starts at \(SleepNow.clock(ActivityLog.rounded(cursor ?? .now)))"
    }

    /// The range an End tap would name: the pin still running at the cursor (or now), up to it.
    private var endingRange: (start: Date, end: Date)? {
        let end = ActivityLog.rounded(cursor ?? .now)
        return log.spans(at: .now).last { $0.start < end && $0.end >= end }.map { ($0.start, end) }
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
        if !activity.isMoment, !activity.asksEnd, endingRange != nil {
            Button("Ended now — name the stretch since the last pin", systemImage: "stop.fill") { record(activity, starts: false) }
        }
        ForEach([5, 15, 30, 60], id: \.self) { minutes in
            Button("Started \(minutes) min ago") { marks.append(ActivityMark(time: ActivityLog.rounded(.now.addingTimeInterval(-Double(minutes) * 60)), tag: activity.id)) }
        }
        if customTags.contains(activity.id) {
            Button("Icon and colour…", systemImage: "paintpalette") { tagEditor = TagTarget(id: activity.id) }
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
            if target != nil || !item.asksEnd || isPlanning { record(item, starts: true) } else { withAnimation(.snappy) { choosing = choosing == key ? nil : key } }
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
        Button { tagEditor = TagTarget(id: "") } label: {
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

    // MARK: Activities

    /// Plans first (with an alarm switch), then today's ranges and moments; earlier days folded into a row each.
    private func activities(spans: [ActivitySpan], moments: [ActivityMark], planned: [ActivitySpan]) -> some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let dots = moments.map { ActivitySpan(id: $0.id, tag: $0.tag, start: $0.time, end: $0.time, isOpen: false) }
        let recent = (spans + dots).sorted { $0.start > $1.start }
        let days = Dictionary(grouping: recent.filter { $0.start < today }) { calendar.startOfDay(for: $0.start) }
            .sorted { $0.key > $1.key }
        return Section {
            if spans.isEmpty, planned.isEmpty {
                Text("Nothing marked yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .whatDidRow()
            }
            ForEach(planned.reversed()) { plan in
                Button {
                    if selected == plan.id {
                        selected = nil
                        cursor = nil
                    } else {
                        selected = plan.id
                        focus = plan.start
                    }
                } label: {
                    let pin = plan.source ?? plan.id
                    PlanRow(span: plan, isOn: plan.id == selected, hasAlarm: marks.first { $0.id == pin }?.alarm == true) {
                        marks = marks.map { $0.id == pin ? ActivityMark(id: $0.id, time: $0.time, tag: $0.tag, alarm: $0.alarm != true, repeats: $0.repeats) : $0 }
                    }
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Edit", systemImage: "slider.horizontal.3") { editing = marks.first { $0.id == (plan.source ?? plan.id) } }
                    Button(plan.source == nil ? "Delete" : "Stop repeating", systemImage: "trash", role: .destructive) {
                        marks.removeAll { $0.id == (plan.source ?? plan.id) }
                    }
                }
                .whatDidRow()
            }
            ForEach(recent.filter { $0.start >= today }) { span in spanRow(span, in: spans) }
            ForEach(days, id: \.key) { day, daySpans in
                Button {
                    withAnimation(.snappy) {
                        if expandedDays.contains(day) { expandedDays.remove(day) } else { expandedDays.insert(day) }
                    }
                } label: { DayRow(day: day, spans: daySpans, isOpen: expandedDays.contains(day)) }
                    .buttonStyle(.plain)
                    .whatDidRow()
                if expandedDays.contains(day) {
                    ForEach(daySpans) { span in spanRow(span, in: spans) }
                }
            }
        } header: {
            SectionLabel("Activities").textCase(nil).padding(.horizontal, Theme.padding).padding(.top, 14)
        }
    }

    private func spanRow(_ span: ActivitySpan, in spans: [ActivitySpan]) -> some View {
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
                if span.tag == Activity.sleep.id {
                    Text("From the Sleep page")
                } else {
                    Button("Edit", systemImage: "slider.horizontal.3") { editing = marks.first { $0.id == span.id } }
                    Button("Delete", systemImage: "trash", role: .destructive) { marks.removeAll { $0.id == span.id } }
                }
            }
            .whatDidRow()
    }

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
}

/// Name (new tags only), icon and colour for a custom tag; a kind too, when the page sorts tags into kinds.
struct TagEditor: View {
    let name: String
    @State var style: TagStyle
    let taken: [String]
    /// Kinds to pick from (Feeling); nil = none.
    var kinds: [(id: String, title: String)]? = nil
    @State var kind = ""
    let onSave: (String, TagStyle, String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var newName = ""

    private var isNew: Bool { name.isEmpty }
    private var trimmed: String { newName.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool {
        !isNew || (!trimmed.isEmpty && !taken.contains { $0.caseInsensitiveCompare(trimmed) == .orderedSame })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: style.symbol)
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(style.tint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        if isNew {
                            TextField("Name", text: $newName)
                        } else {
                            Text(name)
                        }
                    }
                }
                if let kinds {
                    Section {
                        Picker("Kind", selection: $kind) {
                            ForEach(kinds, id: \.id) { Text($0.title).tag($0.id) }
                        }
                    } footer: {
                        Text("One feeling of a kind at a time: starting this ends another of the same kind.")
                    }
                }
                Section("Colour") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                        ForEach(TagStyle.colors, id: \.name) { entry in
                            Button { style.color = entry.name } label: {
                                Circle().fill(entry.color).frame(width: 34, height: 34)
                                    .overlay { if style.color == entry.name { Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.white) } }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(entry.name)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                        ForEach(TagStyle.symbols, id: \.self) { symbol in
                            Button { style.symbol = symbol } label: {
                                Image(systemName: symbol)
                                    .font(.title3)
                                    .frame(width: 40, height: 40)
                                    .foregroundStyle(style.symbol == symbol ? Color.white : style.tint)
                                    .background(style.symbol == symbol ? AnyShapeStyle(style.tint) : AnyShapeStyle(style.tint.opacity(0.12)),
                                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(isNew ? "New activity" : name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "Add" : "Save") {
                        onSave(isNew ? trimmed : name, style, kinds == nil ? nil : kind)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.large])
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

/// A pin ahead of now: when, what, and whether to be told.
private struct PlanRow: View {
    let span: ActivitySpan
    let isOn: Bool
    let hasAlarm: Bool
    let toggleAlarm: () -> Void

    var body: some View {
        let isToday = Calendar.current.isDateInToday(span.start)
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text(SleepNow.clock(span.start))
                    .font(.clock(17, weight: .regular))
                if !isToday {
                    Text(span.start, format: .dateTime.weekday(.abbreviated).day()).font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(minWidth: 64, alignment: .leading)
            Label(span.activity.title, systemImage: span.activity.symbol)
                .foregroundStyle(span.tag == nil ? .secondary : .primary)
                .labelStyle(TintedIconLabelStyle(tint: span.activity.tint))
            Text(span.isDaily ? "every day" : "planned").font(.caption).foregroundStyle(.tertiary)
            Spacer()
            Button(action: toggleAlarm) {
                Image(systemName: hasAlarm ? "bell.fill" : "bell.slash")
                    .foregroundStyle(hasAlarm ? Color.accentColor : .secondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(hasAlarm ? "Alarm on" : "Alarm off")
        }
        .padding(.horizontal, 8)
        .frame(minHeight: 40)
        .background(isOn ? Color.accentColor.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
    }
}

/// One earlier day: its date, how many pins, and where most of it went.
struct DayRow: View {
    let day: Date
    let spans: [ActivitySpan]
    let isOpen: Bool

    var body: some View {
        let totals = Dictionary(grouping: spans.filter { $0.tag != nil && !$0.activity.isMoment }) { $0.tag ?? "" }
            .map { (tag: $0.key, time: $0.value.reduce(0) { $0 + $1.duration }) }
            .sorted { $0.time > $1.time }
            .prefix(3)
        HStack(spacing: 12) {
            Text(day, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                .font(.system(.body, design: .rounded, weight: .semibold))
                .frame(minWidth: 96, alignment: .leading)
            HStack(spacing: 10) {
                ForEach(Array(totals), id: \.tag) { total in
                    let activity = Activity.of(total.tag)
                    HStack(spacing: 3) {
                        Image(systemName: activity.symbol).foregroundStyle(activity.tint)
                        Text(ActivityLog.duration(total.time)).monospacedDigit()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            Spacer()
            Text("\(spans.count)").font(.label).foregroundStyle(.tertiary)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
                .rotationEffect(.degrees(isOpen ? 90 : 0))
        }
        .padding(.horizontal, 8)
        .frame(minHeight: 40)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct SpanRow: View {
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
            if !span.activity.isMoment {
                Text(span.isOpen ? "now" : ActivityLog.duration(span.duration))
                    .font(.label)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .frame(minHeight: 40)
        .background(isOn ? Color.accentColor.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
    }
}

struct TintedIconLabelStyle: LabelStyle {
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
                DatePicker(mark.time > .now ? "Planned for" : "Started", selection: $mark.time)
                Section {
                    Toggle("Repeat every day", isOn: Binding(get: { mark.isDaily }, set: { mark.repeats = $0 ? "daily" : nil }))
                    if mark.time > .now || mark.isDaily {
                        Toggle("Alarm", isOn: Binding(get: { mark.alarm == true }, set: { mark.alarm = $0 }))
                    }
                } footer: {
                    if mark.isDaily { Text("Shows up at \(SleepNow.clock(mark.time)) on the days after, for two weeks ahead.") }
                }
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
                        onSave(ActivityMark(id: mark.id, time: ActivityLog.rounded(mark.time), tag: mark.tag, alarm: mark.alarm, repeats: mark.repeats))
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
