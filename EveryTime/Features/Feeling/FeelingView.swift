import SwiftUI

/// How you've felt through the day: tap a feeling to start it (one of a kind at a time, kinds overlay), tap it again to end it.
struct FeelingView: View {
    @Stored(FeelingLog.key) private var marks: [FeelingMark] = []
    @Stored(CustomFeeling.key) private var custom: [CustomFeeling] = []
    /// The custom feeling being made or restyled; "" = new.
    @State private var tagEditor: TagTarget?

    private struct TagTarget: Identifiable { let id: String }
    @Stored(JetLagKey.profile) private var profile: JetLagProfile? = nil
    /// Nil while following now.
    @State private var cursor: Date?
    @State private var selected: UUID?
    @State private var focus: Date?
    @State private var held: FeelingMark?
    @State private var expandedDays: Set<Date> = []

    private var log: FeelingLog { FeelingLog(marks: marks) }

    var body: some View {
        TimelineView(.everyMinute) { context in
            let now = max(context.date, .now)
            let log = log
            let spans = log.spans(at: now)
            let active = log.active(at: now)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    Section { hero(now: now, spans: spans, active: active).whatDidRow() }
                    activities(spans: spans)
                }
                .padding(.vertical, 8)
                .background {
                    Color.clear.contentShape(Rectangle()).onTapGesture { withAnimation(.snappy) { cursor = nil } }
                }
            }
        }
        .animation(.snappy, value: marks.count)
        .sensoryFeedback(.impact(weight: .medium), trigger: marks.count)
        .navigationTitle("How do I feel?")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { Feeling.custom = custom }
        .sheet(item: $tagEditor) { target in
            let existing = custom.first { $0.name == target.id }
            TagEditor(name: target.id, style: existing?.style ?? TagStyle(), taken: Feeling.all.map(\.title), kinds: Feeling.kinds,
                      kind: existing?.kind ?? "other") { name, style, kind in
                custom.removeAll { $0.name == name }
                custom.append(CustomFeeling(name: name, style: style, kind: kind ?? "other"))
                Feeling.custom = custom
            }
        }
        .confirmationDialog("\(held.map { Feeling.of(tag: Feeling.prefix + $0.feeling)?.title ?? "" } ?? "") at \(held.map { SleepNow.clock($0.start) } ?? "")",
                            isPresented: Binding { held != nil } set: { if !$0 { held = nil } },
                            titleVisibility: .visible, presenting: held) { mark in
            if mark.end == nil { Button("End now") { marks = log.ending(mark.id, at: .now).marks } }
            Button("Delete", role: .destructive) { marks.removeAll { $0.id == mark.id } }
        }
    }

    // MARK: Now

    private func hero(now: Date, spans: [ActivitySpan], active: [FeelingMark]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if active.isEmpty {
                Text("Tap how you feel. One of each kind at a time; a new mood ends the old one, energy and focus run alongside.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(active.sorted { $0.start < $1.start }) { mark in
                        if let feeling = Feeling.of(tag: Feeling.prefix + mark.feeling) {
                            HStack(spacing: 8) {
                                Image(systemName: feeling.symbol).foregroundStyle(feeling.tint).frame(width: 22)
                                Text("\(feeling.title) since \(SleepNow.clock(mark.start))")
                                Spacer()
                                Text(ActivityLog.duration(now.timeIntervalSince(mark.start)))
                                    .font(.clock(17, weight: .medium)).foregroundStyle(.secondary)
                            }
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        }
                    }
                }
            }
            ActivityRing(spans: spans, start: earliest(now: now, spans: spans), now: now, selected: selected,
                         noCoffee: nil, allowsFuture: false, cursor: $cursor, focus: $focus) { id in
                held = marks.first { $0.id == id }
            }
            .frame(maxWidth: 300)
            .frame(maxWidth: .infinity)
            Text(hint(active: active))
                .font(.label)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            grid(active: active)
        }
        .padding(.vertical, 8)
    }

    private func hint(active: [FeelingMark]) -> String {
        let at = SleepNow.clock(ActivityLog.rounded(cursor ?? .now))
        return active.isEmpty ? "Tap a feeling: it starts at \(at)" : "Tap a feeling to start it at \(at); tap one that's on to end it"
    }

    /// Whole days from the first mark (at most two weeks back) through today.
    private func earliest(now: Date, spans: [ActivitySpan]) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let floor = calendar.date(byAdding: .day, value: -14, to: today) ?? today
        let first = spans.first.map { calendar.startOfDay(for: $0.start) } ?? today
        return max(floor, min(first, today))
    }

    private func grid(active: [FeelingMark]) -> some View {
        let cells: [Feeling?] = Feeling.all + [nil]
        let rows = stride(from: 0, to: cells.count, by: 4).map { Array(cells[$0..<min($0 + 4, cells.count)]) }
        return VStack(spacing: 8) {
            ForEach(rows.indices, id: \.self) { r in
                HStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { column in
                        if column < rows[r].count, let feeling = rows[r][column] {
                            let on = active.first { $0.feeling == feeling.id }
                            TagTile(activity: feeling.activity, isOn: on != nil) { tap(feeling, active: on) }
                                .contextMenu {
                                    if custom.contains(where: { $0.name == feeling.id }) {
                                        Button("Icon, colour and kind…", systemImage: "paintpalette") { tagEditor = TagTarget(id: feeling.id) }
                                        Button("Remove from list", systemImage: "minus.circle", role: .destructive) {
                                            custom.removeAll { $0.name == feeling.id }
                                            Feeling.custom = custom
                                        }
                                    }
                                }
                        } else if column < rows[r].count {
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
                        } else {
                            Color.clear.frame(maxWidth: .infinity, minHeight: 58)
                        }
                    }
                }
            }
        }
    }

    /// On: ends it at the cursor (or now). Off: starts it there, ending the same kind.
    private func tap(_ feeling: Feeling, active: FeelingMark?) {
        let time = ActivityLog.rounded(min(cursor ?? .now, .now))
        if let active {
            marks = log.ending(active.id, at: time).marks
        } else {
            marks = log.starting(feeling, at: time).marks
        }
    }

    // MARK: Activities

    private func activities(spans: [ActivitySpan]) -> some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let recent = Array(spans.reversed())
        let days = Dictionary(grouping: recent.filter { $0.start < today }) { calendar.startOfDay(for: $0.start) }
            .sorted { $0.key > $1.key }
        return Section {
            if spans.isEmpty {
                Text("Nothing yet.").font(.subheadline).foregroundStyle(.secondary).whatDidRow()
            }
            ForEach(recent.filter { $0.start >= today }) { span in row(span) }
            ForEach(days, id: \.key) { day, daySpans in
                Button {
                    withAnimation(.snappy) {
                        if expandedDays.contains(day) { expandedDays.remove(day) } else { expandedDays.insert(day) }
                    }
                } label: { DayRow(day: day, spans: daySpans, isOpen: expandedDays.contains(day)) }
                    .buttonStyle(.plain)
                    .whatDidRow()
                if expandedDays.contains(day) {
                    ForEach(daySpans) { span in row(span) }
                }
            }
        } header: {
            SectionLabel("Feelings").textCase(nil).padding(.horizontal, Theme.padding).padding(.top, 14)
        }
    }

    private func row(_ span: ActivitySpan) -> some View {
        Button {
            if selected == span.id {
                selected = nil
                cursor = nil
            } else {
                selected = span.id
                focus = span.start.addingTimeInterval(span.duration / 2)
            }
        } label: { SpanRow(span: span, isOn: span.id == selected) }
            .buttonStyle(.plain)
            .contextMenu {
                if span.isOpen { Button("End now", systemImage: "stop.fill") { marks = log.ending(span.id, at: .now).marks } }
                Button("Delete", systemImage: "trash", role: .destructive) { marks.removeAll { $0.id == span.id } }
            }
            .whatDidRow()
    }
}

#Preview {
    NavigationStack { FeelingView() }
}
