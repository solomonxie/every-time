import SwiftUI

/// Every contraction, event and stage, newest first, by day. Today and yesterday open, older days fold.
/// Tap a row to fix it; swipe or long-press to delete. A folded day deletes as a whole.
struct LaborHistory: View {
    let analysis: LaborAnalysis
    let contractions: [Contraction]
    let events: [LaborEvent]
    let edit: (Contraction) -> Void
    let editEvent: (LaborEvent) -> Void
    let delete: ([UUID]) -> Void

    @State private var toggled: Set<Date> = []
    @State private var confirmsDay: Date?

    private enum Item: Identifiable {
        case contraction(Contraction)
        case event(LaborEvent)
        var id: UUID { switch self { case .contraction(let c): c.id; case .event(let e): e.id } }
        var time: Date { switch self { case .contraction(let c): c.start; case .event(let e): e.time } }
        var isContraction: Bool { if case .contraction(let c) = self { !LaborAnalysis.isMisTap(c) } else { false } }
    }

    var body: some View {
        let calendar = Calendar.current
        let items = (contractions.map(Item.contraction) + events.map(Item.event)).sorted { $0.time > $1.time }
        let days = Dictionary(grouping: items) { calendar.startOfDay(for: $0.time) }
        let recent = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: analysis.now)) ?? analysis.now
        let intervals = LaborAnalysis.allIntervals(contractions)
        Section {
            if items.isEmpty {
                Text("Contractions and events you log show up here").font(.subheadline).foregroundStyle(.secondary).laborRow()
            }
            ForEach(days.keys.sorted(by: >), id: \.self) { day in
                let dayItems = days[day] ?? []
                let isOpen = (day >= recent) != toggled.contains(day)
                dayRow(day, items: dayItems, isOpen: isOpen)
                if isOpen {
                    ForEach(dayItems) { row($0, intervals: intervals) }
                }
            }
        } header: {
            SectionLabel("Timeline").textCase(nil)
        } footer: {
            if !items.isEmpty {
                Text("Tap a row to fix it. Swipe left or long-press to delete.").font(.caption).laborRow()
            }
        }
        .confirmationDialog("Delete everything from this day?", isPresented: Binding(get: { confirmsDay != nil }, set: { if !$0 { confirmsDay = nil } }),
                            titleVisibility: .visible) {
            Button("Delete day", role: .destructive) {
                if let day = confirmsDay { delete((days[day] ?? []).map(\.id)) }
                confirmsDay = nil
            }
        }
    }

    private func dayRow(_ day: Date, items: [Item], isOpen: Bool) -> some View {
        Button {
            withAnimation(.snappy) { if toggled.contains(day) { toggled.remove(day) } else { toggled.insert(day) } }
        } label: {
            HStack {
                Text(day, format: .dateTime.weekday(.wide).month(.abbreviated).day()).font(.subheadline.weight(.semibold))
                Text("^[\(items.filter(\.isContraction).count) contraction](inflect: true)").font(.label).foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "chevron.right").rotationEffect(.degrees(isOpen ? 90 : 0)).foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .laborRow()
        .swipeActions { Button("Delete day", role: .destructive) { confirmsDay = day } }
        .contextMenu { Button("Delete day", systemImage: "trash", role: .destructive) { confirmsDay = day } }
    }

    @ViewBuilder
    private func row(_ item: Item, intervals: [UUID: TimeInterval]) -> some View {
        switch item {
        case .contraction(let c):
            Button { edit(c) } label: { ContractionRow(contraction: c, interval: intervals[c.id], now: analysis.now) }
                .buttonStyle(.plain)
                .laborRow()
                .swipeActions { Button("Delete", role: .destructive) { delete([c.id]) } }
                .contextMenu {
                    Button("Edit", systemImage: "pencil") { edit(c) }
                    Button("Delete", systemImage: "trash", role: .destructive) { delete([c.id]) }
                }
        case .event(let e):
            Button { editEvent(e) } label: {
                HStack(spacing: 12) {
                    Text(LaborAnalysis.time(e.time)).font(.clock(15, weight: .regular)).foregroundStyle(.secondary).frame(width: 78, alignment: .leading)
                    Label(e.title, systemImage: e.kind.symbol)
                        .font(.subheadline.weight(e.kind == .stage ? .semibold : .regular))
                        .foregroundStyle(e.kind.isWarning ? Theme.Tone.warn : e.kind == .stage ? Color.accentColor : .primary)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .laborRow()
            .swipeActions { Button("Delete", role: .destructive) { delete([e.id]) } }
            .contextMenu {
                Button("Edit time", systemImage: "clock") { editEvent(e) }
                Button("Delete", systemImage: "trash", role: .destructive) { delete([e.id]) }
            }
        }
    }
}

private struct ContractionRow: View {
    let contraction: Contraction
    let interval: TimeInterval?
    let now: Date

    var body: some View {
        HStack(spacing: 12) {
            Text(LaborAnalysis.time(contraction.start)).font(.clock(15, weight: .regular)).foregroundStyle(.secondary)
                .frame(width: 78, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(contraction.length.map { "Lasted " + LaborAnalysis.clock($0) } ?? "Timing " + LaborAnalysis.clock(now.timeIntervalSince(contraction.start)))
                    .font(.subheadline.weight(.medium))
                    .strikethrough(!LaborAnalysis.countsLength(contraction) && contraction.end != nil)
                if let interval {
                    Text("\(LaborAnalysis.clock(interval)) after the one before").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let note = Self.note(contraction) {
                Text(note).font(.caption).foregroundStyle(Theme.Tone.warn)
            } else if let strength = contraction.strength {
                Text(strength.title).font(.subheadline)
            }
        }
        .contentShape(Rectangle())
    }

    static func note(_ c: Contraction) -> String? {
        if LaborAnalysis.isMisTap(c) { return "too short · not counted" }
        if let length = c.length, length > LaborAnalysis.maxLength { return "too long · tap to fix" }
        return nil
    }
}

struct ContractionEditor: View {
    @State var contraction: Contraction
    /// The rest of the timeline, to keep contractions from overlapping.
    let others: [Contraction]
    let save: (Contraction) -> Void
    let delete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var length: Int = 60

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Started", selection: $contraction.start, in: ...Date.now, displayedComponents: [.date, .hourAndMinute])
                    if contraction.end != nil {
                        Stepper(value: $length, in: Int(LaborAnalysis.minLength)...300, step: 5) {
                            LabeledContent("Length", value: LaborAnalysis.clock(TimeInterval(length)))
                        }
                    }
                    Picker("Strength", selection: $contraction.strength) {
                        Text("—").tag(Contraction.Strength?.none)
                        ForEach(Contraction.Strength.allCases, id: \.self) { Text($0.title).tag(Contraction.Strength?.some($0)) }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    if let clash { Text("Overlaps the one at \(LaborAnalysis.time(clash.start)).").foregroundStyle(Theme.Tone.bad) }
                }
                Section {
                    Button("Delete contraction", role: .destructive) { delete(); dismiss() }
                }
            }
            .navigationTitle("Contraction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save(edited)
                        dismiss()
                    }
                    .disabled(clash != nil)
                }
            }
            .onAppear { length = Int((contraction.length ?? 60).rounded()) }
        }
        .presentationDetents([.medium])
    }

    private var edited: Contraction {
        var c = contraction
        if c.end != nil { c.end = c.start.addingTimeInterval(TimeInterval(length)) }
        return c
    }

    static func clash(_ c: Contraction, with others: [Contraction]) -> Contraction? {
        let end = max(c.end ?? c.start, c.start.addingTimeInterval(1))
        return others.first { $0.id != c.id && $0.start < end && ($0.end ?? $0.start.addingTimeInterval(1)) > c.start }
    }

    private var clash: Contraction? { Self.clash(edited, with: others) }
}

/// Fix when something happened ("waters broke 20 min ago").
struct LaborEventEditor: View {
    @State var event: LaborEvent
    let save: (LaborEvent) -> Void
    let delete: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                LabeledContent("What", value: event.title)
                DatePicker("When", selection: $event.time, in: ...Date.now, displayedComponents: [.date, .hourAndMinute])
                Section {
                    Button("Delete", role: .destructive) { delete(); dismiss() }
                }
            }
            .navigationTitle(event.kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save(event); dismiss() } }
            }
        }
        .presentationDetents([.medium])
    }
}
