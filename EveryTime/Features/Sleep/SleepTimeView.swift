import SwiftUI

/// "When to sleep?": what sleeping now means (nap, early night or cycle wake times), tonight's plan and the nap log.
struct SleepTimeView: View {
    @Stored(JetLagKey.profile) private var profile: JetLagProfile? = nil
    @Stored(NapKey.naps) private var naps: [Nap] = []
    @Stored(NapKey.active) private var active: ActiveNap? = nil
    @Stored(NapKey.night) private var plan: NightPlan? = nil
    @State private var offset = 0
    @State private var picked: String?
    @State private var showsAllNaps = false
    @State private var sheet: SheetKind?
    @State private var openField: NightField?

    private enum NightField { case bed, wake, bedtimes }

    private enum SheetKind: String, Identifiable {
        case profile, log
        var id: String { rawValue }
    }

    private var advice: NapAdvice { NapAdvice(profile: profile ?? JetLagProfile(), plan: plan) }

    var body: some View {
        TimelineView(.everyMinute) { context in
            let now = context.date
            let sleepNow = SleepNow(advice: advice, start: now.addingTimeInterval(Double(offset) * 60))
            let options = sleepNow.options
            let selected = options.first { $0.id == picked } ?? options.first(where: \.isRecommended) ?? options.first
            List {
                Section {
                    Group {
                        if let active {
                            NapInProgress(nap: active, advice: advice)
                        } else {
                            nowCard(sleepNow, options: options, selected: selected)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: Theme.padding, bottom: 20, trailing: Theme.padding))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                Section {
                    tonightCard(now: now, day: sleepNow.day).napRow()
                } header: {
                    SectionLabel(title: "Tonight") {
                        if plan(for: sleepNow.day) != nil {
                            Button("Use usual") { withAnimation(.snappy) { plan = nil } }
                                .font(.label)
                                .buttonStyle(.borderless)
                        }
                    }
                    .textCase(nil)
                }
                if let nap = unratedNap(now: now) {
                    Section { ratePrompt(nap).napRow() } header: { SectionLabel("Last nap").textCase(nil) }
                }
                if naps.filter({ $0.night != nil }).count >= 3 {
                    Section { pattern.napRow() } header: { SectionLabel("Your nights after naps").textCase(nil) }
                }
                history
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .bottomBar { bottomBar(selected, day: sleepNow.day) }
        }
        .animation(.snappy, value: naps)
        .animation(.snappy, value: active)
        .animation(.snappy, value: picked)
        .animation(.snappy, value: offset)
        .navigationTitle("When to sleep?")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $sheet) { kind in
            switch kind {
            case .profile:
                JetLagProfileSheet(profile: profile ?? JetLagProfile(), showsAdvice: false) { profile = $0 }
            case .log:
                LogNapSheet { naps.insert($0, at: 0); naps.sort { $0.start > $1.start } }
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: active == nil)
        .sensoryFeedback(.selection, trigger: picked)
        .sensoryFeedback(.selection, trigger: offset)
    }

    // MARK: Sleep now

    private func nowCard(_ sleepNow: SleepNow, options: [SleepNow.Option], selected: SleepNow.Option?) -> some View {
        let verdict = sleepNow.verdict
        return VStack(alignment: .leading, spacing: Theme.spacing) {
            HStack(spacing: 4) {
                Text("If I sleep")
                offsetMenu(start: sleepNow.start)
                Spacer()
                InfoButton(label: "About naps and sleep cycles", text: Self.info)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(verdict.headline)
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                if !verdict.reason.isEmpty {
                    Text(verdict.reason)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Card(padding: 6) {
                VStack(spacing: 0) {
                    ForEach(options) { option in
                        let isSelected = option.id == selected?.id
                        OptionRow(option: option, isSelected: isSelected,
                                  segments: isSelected ? sleepNow.segments(for: option) : [],
                                  bed: sleepNow.day.bed) { picked = option.id }
                    }
                }
            }
            if let tip = sleepNow.tip {
                Label(tip, systemImage: "lightbulb")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func offsetMenu(start: Date) -> some View {
        Menu {
            Picker("Sleep", selection: $offset) {
                ForEach(SleepNow.offsets, id: \.self) { Text(Self.offsetText($0)).tag($0) }
            }
        } label: {
            HStack(spacing: 3) {
                Text(offset == 0 ? "now" : "\(Self.offsetText(offset)), at \(SleepNow.clock(start))")
                Image(systemName: "chevron.up.chevron.down").font(.caption2.weight(.semibold))
            }
            .foregroundStyle(Color.accentColor)
        }
    }

    private static func offsetText(_ minutes: Int) -> String {
        minutes == 0 ? "now" : minutes < 60 ? "in \(minutes) min" : "in \(minutes / 60) h"
    }

    @ViewBuilder
    private func bottomBar(_ selected: SleepNow.Option?, day: NapAdvice.Day) -> some View {
        if let active {
            HStack(spacing: Theme.spacing) {
                Button("Cancel") {
                    NapAlarm.cancel()
                    self.active = nil
                }
                .buttonStyle(.soft)
                Button("I'm up") { finish(active) }
                    .buttonStyle(.primary)
            }
        } else {
            HStack(spacing: Theme.spacing) {
                Button { sheet = .log } label: { Label("Log", systemImage: "plus") }
                    .buttonStyle(.soft)
                    .fixedSize()
                    .accessibilityLabel("Log a past nap")
                primaryAction(selected, day: day)
            }
        }
    }

    @ViewBuilder
    private func primaryAction(_ selected: SleepNow.Option?, day: NapAdvice.Day) -> some View {
        if case .nap(let minutes)? = selected?.kind {
            Button { startNap(minutes) } label: {
                Label("Nap \(minutes) min · wake at \(Self.wakeText(minutes))", systemImage: "powersleep")
            }
            .buttonStyle(.primary)
        } else if case .bedAt(let bed)? = selected?.kind, !Calendar.current.isDate(bed, equalTo: day.bed, toGranularity: .minute) {
            Button {
                planBinding(\.bed, day: day).wrappedValue = Calendar.current.component(.hour, from: bed) * 60
                    + Calendar.current.component(.minute, from: bed)
            } label: {
                Label("Plan bed at \(SleepNow.clock(bed)) tonight", systemImage: "bed.double")
            }
            .buttonStyle(.primary)
        } else {
            Menu {
                ForEach(NapAdvice.lengths, id: \.self) { minutes in
                    Button("\(minutes) min · wake at \(Self.wakeText(minutes))") { startNap(minutes) }
                }
            } label: {
                Label("Start a nap", systemImage: "powersleep")
            }
            .buttonStyle(.primary)
        }
    }

    private func startNap(_ minutes: Int) {
        let nap = ActiveNap(start: .now, minutes: minutes)
        active = nap
        Task { await NapAlarm.schedule(nap) }
    }

    private static func wakeText(_ minutes: Int) -> String {
        SleepNow.clock(Date.now.addingTimeInterval(Double(minutes) * 60))
    }

    private func finish(_ nap: ActiveNap) {
        NapAlarm.cancel()
        let day = advice.current(at: nap.start)
        naps.insert(Nap(start: nap.start, end: .now, bed: plan(for: day) == nil ? nil : day.bed), at: 0)
        active = nil
    }

    // MARK: Tonight

    private func tonightCard(now: Date, day: NapAdvice.Day) -> some View {
        let window = advice.window(on: day.wake)
        return Card {
            timeRow("Bed", .bed, minutes: planBinding(\.bed, day: day))
            timeRow("Wake", .wake, minutes: planBinding(\.wake, day: day))
            LabeledContent("Sleep") { Text(NapAdvice.hours(day.nightHours)).monospacedDigit() }
            if let note = advice.nightNote(on: day.wake) {
                Label(note, systemImage: "lightbulb")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            UnfoldingRow(id: NightField.bedtimes, open: $openField) {
                Text("Bedtimes")
            } value: {
                Text("to wake at \(SleepNow.clock(day.nextWake))").foregroundStyle(.secondary)
            } picker: {
                VStack(spacing: 8) {
                    ForEach(SleepSuggestion.bedtimes(wakingAt: day.nextWake)) { suggestion in
                        SuggestionRow(suggestion: suggestion, isPassed: suggestion.time < now)
                    }
                }
            }
            .buttonStyle(.borderless)
            LabeledContent("Nap window") {
                Text("\(SleepNow.clock(window.start)) – \(SleepNow.clock(window.end))").monospacedDigit()
            }
            Button { sheet = .profile } label: {
                LabeledContent("Usual sleep") {
                    HStack(spacing: 8) {
                        Text(profileSummary).foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .tint(.primary)
        }
    }

    private func timeRow(_ title: String, _ field: NightField, minutes: Binding<Int>) -> some View {
        UnfoldingRow(id: field, open: $openField) {
            Text(title)
        } value: {
            Text(minutes.wrappedValue.timeOfDayText).monospacedDigit()
        } picker: {
            DatePicker(title, selection: minutes.timeOfDay, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderless)
    }

    /// The plan for the night `day` leads into, if one is set.
    private func plan(for day: NapAdvice.Day) -> NightPlan? {
        plan.flatMap { Calendar.current.isDate($0.day, inSameDayAs: day.wake) ? $0 : nil }
    }

    /// Edits the plan for `day`'s night, starting from the usual hours.
    private func planBinding(_ field: WritableKeyPath<NightPlan, Int>, day: NapAdvice.Day) -> Binding<Int> {
        let usual = profile ?? JetLagProfile()
        let current = plan(for: day)
            ?? NightPlan(day: Calendar.current.startOfDay(for: day.wake), bed: usual.usualBedtime, wake: usual.usualWake)
        return Binding {
            current[keyPath: field]
        } set: { value in
            var edited = current
            edited[keyPath: field] = value
            plan = edited.bed == usual.usualBedtime && edited.wake == usual.usualWake ? nil : edited
        }
    }

    private var profileSummary: String {
        guard let profile else { return "Not set" }
        return "\(profile.usualBedtime.timeOfDayText) – \(profile.usualWake.timeOfDayText)"
    }

    private static let info = NapAdvice.info + """
        \n\nA sleep cycle is about 90 minutes; waking between cycles feels easier, and 5–6 cycles \
        is a full night. Wake times include ~15 minutes to fall asleep.
        """

    // MARK: Nights

    private func unratedNap(now: Date) -> Nap? {
        naps.first { nap in
            nap.night == nil && !Calendar.current.isDate(nap.start, inSameDayAs: now)
                && now.timeIntervalSince(nap.start) < 3 * 86_400
        }
    }

    private func ratePrompt(_ nap: Nap) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How was the night after \(nap.start.formatted(.dateTime.weekday(.wide)))'s \(nap.minutes)-minute nap at \(nap.start.formatted(date: .omitted, time: .shortened))?")
                .font(.subheadline)
            HStack(spacing: 8) {
                ForEach(Nap.Night.allCases) { night in
                    Button { rate(nap, night) } label: {
                        Label(night.title, systemImage: night.symbol)
                            .font(.label)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 10)
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(Theme.cardFill, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// Nights grouped by the effect the advice predicted, so the rules can be checked against you.
    private var pattern: some View {
        let rated = naps.filter { $0.night != nil }
        return VStack(alignment: .leading, spacing: 8) {
            ForEach([NapAdvice.Level.low, .some, .high], id: \.self) { level in
                let group = rated.filter { advice.tonight(start: $0.start, minutes: $0.minutes, bed: $0.bed) == level }
                if !group.isEmpty {
                    HStack {
                        Circle().fill(level.tint).frame(width: 8, height: 8)
                        Text(NapAdvice.tonightText(level)).font(.subheadline)
                        Spacer()
                        Text("\(group.filter { $0.night == .good }.count) of \(group.count) good")
                            .font(.label).monospacedDigit().foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func rate(_ nap: Nap, _ night: Nap.Night?) {
        guard let i = naps.firstIndex(where: { $0.id == nap.id }) else { return }
        naps[i].night = night
    }

    // MARK: History

    private var history: some View {
        Section {
            if naps.isEmpty {
                Text("No naps yet — start one, or log a past nap with + Log below")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .napRow()
            }
            ForEach(showsAllNaps ? naps : Array(naps.prefix(Self.recentNaps))) { nap in
                NapRow(nap: nap, level: advice.tonight(start: nap.start, minutes: nap.minutes, bed: nap.bed))
                    .napRow()
                    .contextMenu {
                        ForEach(Nap.Night.allCases) { night in
                            Button(night.title, systemImage: night.symbol) { rate(nap, night) }
                        }
                        if nap.night != nil {
                            Button("Clear rating", systemImage: "xmark") { rate(nap, nil) }
                        }
                    }
            }
            .onDelete { naps.remove(atOffsets: $0) }
            if !showsAllNaps, naps.count > Self.recentNaps {
                Button("Show all \(naps.count)") { showsAllNaps = true }
                    .font(.label)
                    .napRow()
            }
        } header: {
            SectionLabel("Naps").textCase(nil)
        }
    }

    private static let recentNaps = 5
}

private struct OptionRow: View {
    let option: SleepNow.Option
    let isSelected: Bool
    let segments: [SleepNow.Segment]
    let bed: Date
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Circle().fill(option.level.tint).frame(width: 8, height: 8)
                    Text(option.title)
                        .font(.system(.body, design: .rounded, weight: isSelected ? .semibold : .regular))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    if option.isRecommended {
                        Text("Best")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15), in: Capsule())
                    }
                    Spacer(minLength: 8)
                    Text(SleepNow.clock(option.time))
                        .font(.clock(18, weight: isSelected ? .regular : .light))
                        .monospacedDigit()
                        .foregroundStyle(isSelected ? .primary : .secondary)
                }
                if isSelected {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(option.detail)
                            .font(.label)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        SleepTimeline(segments: segments, bed: bed)
                    }
                    .padding(.leading, 18)
                }
            }
            .padding(10)
            .background(isSelected ? Color.accentColor.opacity(0.1) : .clear,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// What the selected option does between now and the wake, with bedtime marked.
private struct SleepTimeline: View {
    let segments: [SleepNow.Segment]
    let bed: Date

    private var start: Date { segments.first?.start ?? .now }
    private var end: Date { segments.last?.end ?? .now }
    private var showsBed: Bool { bed > start && bed < end }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                let span = max(1, end.timeIntervalSince(start))
                let x = { (date: Date) in geo.size.width * date.timeIntervalSince(start) / span }
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.1))
                    ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                        Rectangle()
                            .fill(Self.color(segment.kind))
                            .frame(width: max(1, x(segment.end) - x(segment.start)))
                            .offset(x: x(segment.start))
                    }
                    if showsBed {
                        Rectangle().fill(Color.primary.opacity(0.7)).frame(width: 2).offset(x: x(bed) - 1)
                    }
                }
                .clipShape(Capsule())
            }
            .frame(height: 8)
            HStack {
                Text(SleepNow.clock(start))
                Spacer()
                if showsBed { Text("bed \(SleepNow.clock(bed))") }
                Spacer()
                Text(SleepNow.clock(end))
            }
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(segments.map { "\(Self.name($0.kind)) \(SleepNow.clock($0.start)) to \(SleepNow.clock($0.end))" }
            .joined(separator: ", "))
    }

    private static func color(_ kind: SleepNow.Segment.Kind) -> Color {
        switch kind {
        case .awake: .clear
        case .nap: .accentColor
        case .sleep: .indigo
        case .restless: Theme.Tone.bad
        case .drift: Theme.Tone.warn
        }
    }

    private static func name(_ kind: SleepNow.Segment.Kind) -> String {
        switch kind {
        case .awake: "Awake"
        case .nap: "Nap"
        case .sleep: "Sleep"
        case .restless: "Likely awake"
        case .drift: "Slow to fall asleep"
        }
    }
}

private struct SuggestionRow: View {
    let suggestion: SleepSuggestion
    let isPassed: Bool

    private var isHighlighted: Bool { suggestion.isRecommended && !isPassed }

    var body: some View {
        HStack(alignment: .center, spacing: Theme.spacing) {
            Text(suggestion.time, format: .dateTime.hour().minute())
                .font(.clock(20, weight: isHighlighted ? .regular : .light))
                .strikethrough(isPassed)
                .frame(maxWidth: .infinity, alignment: .leading)
            CycleBar(cycles: suggestion.cycles, isHighlighted: isHighlighted)
            Text("\(suggestion.hours.formatted(.number.precision(.fractionLength(0...1))))h")
                .font(.subheadline)
                .fontWeight(isHighlighted ? .semibold : .regular)
                .monospacedDigit()
                .frame(width: 40, alignment: .trailing)
        }
        .foregroundStyle(isHighlighted ? .primary : .secondary)
        .opacity(isPassed ? 0.45 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(suggestion.time.formatted(.dateTime.hour().minute())), \(suggestion.cycles) cycles")
        .accessibilityValue(isPassed ? "Passed" : suggestion.isRecommended ? "Recommended" : "")
    }
}

/// One segment per sleep cycle, out of the maximum offered.
private struct CycleBar: View {
    let cycles: Int
    let isHighlighted: Bool

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<(SleepSuggestion.cycleCounts.max() ?? 6), id: \.self) { index in
                Capsule()
                    .fill(index < cycles ? (isHighlighted ? Color.accentColor : Color.secondary) : Theme.hairline)
                    .frame(width: 6, height: 16)
            }
        }
    }
}

#Preview {
    NavigationStack { SleepTimeView() }
}
