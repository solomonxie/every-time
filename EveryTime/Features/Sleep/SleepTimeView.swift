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
                if let active {
                    Section {
                        NapInProgress(nap: active, advice: advice)
                            .listRowInsets(EdgeInsets(top: 8, leading: Theme.padding, bottom: 12, trailing: Theme.padding))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                }
                Section {
                    tonightCard(day: sleepNow.day).napRow()
                } header: {
                    SectionLabel(title: "Tomorrow") {
                        InfoButton(label: "About tomorrow", text: Self.tonightInfo)
                    }
                    .textCase(nil)
                }
                if active == nil {
                    Section {
                        optionsCard(options: options, selected: selected).napRow()
                    } header: {
                        SectionLabel(title: "Your options") {
                            InfoButton(label: "About the options", text: Self.optionsInfo)
                        }
                        .textCase(nil)
                    }
                }
                Section {
                    guideCard(now: now, day: sleepNow.day).napRow()
                } header: {
                    SectionLabel("Today's guide").textCase(nil)
                }
                if active == nil {
                    Section {
                        sleepNowCard(sleepNow, selected: selected)
                            .listRowInsets(EdgeInsets(top: 8, leading: Theme.padding, bottom: 12, trailing: Theme.padding))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                }
                howItWorks
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
            .bottomBar { napControls }
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

    /// The option list; picking one updates "If I sleep now" below.
    private func optionsCard(options: [SleepNow.Option], selected: SleepNow.Option?) -> some View {
        Card(padding: 6) {
            VStack(spacing: 0) {
                ForEach(options) { option in
                    OptionRow(option: option, isSelected: option.id == selected?.id) {
                        picked = picked == option.id ? nil : option.id
                    }
                }
            }
        }
    }

    /// When you'd lie down, the verdict, and what the picked option does until tomorrow's wake.
    private func sleepNowCard(_ sleepNow: SleepNow, selected: SleepNow.Option?) -> some View {
        let verdict = sleepNow.verdict
        return VStack(alignment: .leading, spacing: Theme.spacing) {
            HStack(alignment: .firstTextBaseline) {
                Text(offset == 0 ? "If I sleep now" : "If I sleep at \(SleepNow.clock(sleepNow.start))")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer()
                InfoButton(label: "About this page", text: Self.pageInfo)
            }
            Picker("When", selection: $offset) {
                ForEach(SleepNow.offsets, id: \.self) { Text(Self.offsetText($0)).tag($0) }
            }
            .pickerStyle(.segmented)
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
            .padding(.top, 4)
            if let selected {
                Card {
                    HStack(alignment: .firstTextBaseline) {
                        Text(selected.title).font(.cardTitle)
                        Spacer()
                        Text("\(OptionRow.caption(selected.kind)) \(SleepNow.clock(selected.time))")
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    ForEach(effects(of: selected, start: sleepNow.start), id: \.self) { effect in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: effect.symbol)
                                .foregroundStyle(effect.level.tint)
                                .frame(width: 20)
                            Text(effect.text)
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    SleepTimeline(segments: sleepNow.segments(for: selected), bed: sleepNow.day.bed)
                        .padding(.top, 4)
                    selectedAction(selected, day: sleepNow.day)
                        .buttonStyle(.borderless)
                        .padding(.top, 4)
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

    private static func offsetText(_ minutes: Int) -> String {
        minutes == 0 ? "Now" : minutes < 60 ? "In \(minutes) min" : "In \(minutes / 60) h"
    }

    /// What an option does, one line each with its own colour.
    private func effects(of option: SleepNow.Option, start: Date) -> [OptionRow.Effect] {
        switch option.kind {
        case .nap(let minutes):
            let tonight = advice.tonight(start: start, minutes: minutes, bed: advice.current(at: start).bed)
            let groggy = NapAdvice.grogginess(minutes: minutes)
            return [OptionRow.Effect(symbol: "moon.zzz", text: NapAdvice.tonightText(tonight), level: tonight),
                    OptionRow.Effect(symbol: "sun.max", text: NapAdvice.wakeText(minutes: minutes), level: groggy)]
        case .bedAt:
            return [OptionRow.Effect(symbol: "bed.double", text: option.detail, level: option.level)]
        case .splitNight:
            return [OptionRow.Effect(symbol: "exclamationmark.triangle", text: option.detail, level: option.level)]
        case .night:
            return [OptionRow.Effect(symbol: "alarm", text: option.detail, level: option.level)]
        }
    }

    /// Only while napping; otherwise nap actions live in the page.
    @ViewBuilder
    private var napControls: some View {
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
        }
    }

    /// What the picked option can do right away, if anything.
    @ViewBuilder
    private func selectedAction(_ selected: SleepNow.Option, day: NapAdvice.Day) -> some View {
        switch selected.kind {
        case .nap(let minutes):
            Button { startNap(minutes) } label: {
                Label("Start \(minutes)-min nap", systemImage: "powersleep").pill()
            }
        case .bedAt(let bed) where !Calendar.current.isDate(bed, equalTo: day.bed, toGranularity: .minute):
            Button { planBinding(\.bed, day: day).wrappedValue = Self.minutes(of: bed) } label: {
                Label("Use as tonight's bed", systemImage: "bed.double").pill()
            }
        case .night(_, let wake) where !Calendar.current.isDate(wake, equalTo: day.nextWake, toGranularity: .minute):
            Button { planBinding(\.wake, day: day).wrappedValue = Self.minutes(of: wake) } label: {
                Label("Use as tomorrow's wake", systemImage: "alarm").pill()
            }
        default:
            EmptyView()
        }
    }

    private var napMenu: some View {
        Menu {
            ForEach(NapAdvice.lengths, id: \.self) { minutes in
                Button("\(minutes) min · wake at \(Self.wakeText(minutes))") { startNap(minutes) }
            }
        } label: {
            Label("Start a nap", systemImage: "powersleep").pill()
        }
    }

    private static func minutes(of date: Date) -> Int {
        Calendar.current.component(.hour, from: date) * 60 + Calendar.current.component(.minute, from: date)
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

    private func tonightCard(day: NapAdvice.Day) -> some View {
        let cycles = max(0, Int((day.nightHours * 3600 - SleepSuggestion.fallAsleepTime) / SleepSuggestion.cycleLength))
        return Card {
            timeRow("Wake up", symbol: "alarm", .wake, minutes: planBinding(\.wake, day: day))
            timeRow("Bed tonight", symbol: "bed.double", .bed, minutes: planBinding(\.bed, day: day))
            LabeledContent {
                Text("\(NapAdvice.hours(day.nightHours)) · \(cycles) \(cycles == 1 ? "cycle" : "cycles")").monospacedDigit()
            } label: {
                Label("Sleep length", systemImage: "moon.zzz")
            }
            if plan(for: day) != nil {
                Button {
                    withAnimation(.snappy) {
                        plan = nil
                        picked = nil
                    }
                } label: {
                    Label(profile == nil ? "Back to usual" : "Back to usual · \(profileSummary)", systemImage: "arrow.uturn.backward")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                Text("Changed for tonight only.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let note = advice.nightNote(on: day.wake) {
                Label(note, systemImage: "lightbulb")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func guideCard(now: Date, day: NapAdvice.Day) -> some View {
        let window = advice.window(on: day.wake)
        return Card {
            LabeledContent {
                Text("\(SleepNow.clock(window.start)) – \(SleepNow.clock(window.end))").monospacedDigit()
            } label: {
                infoLabel("Best nap window", info: Self.windowInfo)
            }
            UnfoldingRow(id: NightField.bedtimes, open: $openField) {
                infoLabel("Bedtimes", info: Self.bedtimesInfo)
            } value: {
                let best = SleepSuggestion.bedtimes(wakingAt: day.nextWake).first { $0.isRecommended && $0.time >= now }
                Text(best.map { "best \(SleepNow.clock($0.time))" } ?? "see list").foregroundStyle(.secondary)
            } picker: {
                VStack(spacing: 8) {
                    ForEach(SleepSuggestion.bedtimes(wakingAt: day.nextWake)) { suggestion in
                        SuggestionRow(suggestion: suggestion, isPassed: suggestion.time < now)
                    }
                }
            }
            .buttonStyle(.borderless)
            Button { sheet = .profile } label: {
                LabeledContent {
                    HStack(spacing: 8) {
                        Text(profileSummary).foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                } label: {
                    infoLabel("Usual sleep", info: Self.usualInfo)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .tint(.primary)
        }
    }

    private func infoLabel(_ title: String, info: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
            InfoButton(label: "About \(title.lowercased())", text: info)
                .font(.footnote)
        }
    }

    private func timeRow(_ title: String, symbol: String, _ field: NightField, minutes: Binding<Int>) -> some View {
        UnfoldingRow(id: field, open: $openField) {
            Label(title, systemImage: symbol)
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

    private static let pageInfo = """
        Pick when you'd lie down. The page says whether that's a nap, an early night or \
        bedtime, lists what you could do, and shows how each choice plays out until tomorrow's wake.
        """

    private static let optionsInfo = """
        Tap an option to see what it does under "If I sleep now". Green: little effect. Orange: some effect. \
        Red: likely to hurt tonight's sleep or leave you groggy. "Best" is the pick for right now.

        The bar runs from now to tomorrow's wake: blue = nap, indigo = sleep, \
        orange = slow to fall asleep, red = likely awake. The line marks bedtime.
        """

    private static let tonightInfo = """
        Tomorrow's wake and tonight's bed. Change them for tonight only — \
        "Back to usual" undoes it. The options below are worked out against this plan, \
        so changing it (or tapping "Use as…") changes which options show.
        """

    private static let windowInfo = """
        The post-lunch dip, from about 6 hours after you wake. It ends early enough \
        that a short nap doesn't eat into tonight's sleep.
        """

    private static let bedtimesInfo = """
        Times to fall asleep so you wake between cycles. A cycle is ~90 minutes; \
        5–6 cycles is a full night. Times include ~15 minutes to fall asleep.
        """

    private static let usualInfo = """
        Your usual bed and wake times and age. Every suggestion here is worked out from them.
        """

    private static let napsInfo = """
        Rate how each night went after a nap. After 3 ratings you'll see whether \
        the advice matches how you actually sleep.
        """

    private var howItWorks: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Self.howItWorksLines, id: \.self) { line in
                    Label(line, systemImage: "circle.fill")
                        .labelStyle(BulletLabelStyle())
                }
                Text(NapAdvice.info)
                    .padding(.top, 4)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .napRow()
        } header: {
            SectionLabel("How this works").textCase(nil)
        }
    }

    private static let howItWorksLines = [
        "A sleep cycle is about 90 minutes. Waking between cycles feels easier; 5–6 cycles is a full night.",
        "Wake times include about 15 minutes to fall asleep.",
        "Green = little effect, orange = some, red = likely to hurt tonight's sleep or leave you groggy.",
        "Naps get a wake alarm, plus a backup 3 minutes later.",
    ]

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
            HStack(spacing: Theme.spacing) {
                Button { sheet = .log } label: { Label("Add past nap", systemImage: "plus").pill() }
                napMenu
                Spacer(minLength: 0)
            }
            .buttonStyle(.borderless)
            .napRow()
            if naps.isEmpty {
                Text("No naps yet.")
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
            SectionLabel(title: "Naps") {
                InfoButton(label: "About the nap log", text: Self.napsInfo)
            }
            .textCase(nil)
        }
    }

    private static let recentNaps = 5
}

private struct OptionRow: View {
    struct Effect: Hashable {
        let symbol: String
        let text: String
        let level: NapAdvice.Level
    }

    let option: SleepNow.Option
    let isSelected: Bool
    let select: () -> Void

    /// What an option's time means.
    static func caption(_ kind: SleepNow.Option.Kind) -> String {
        switch kind {
        case .bedAt: "bed at"
        case .splitNight: "wake around"
        case .nap, .night: "wake at"
        }
    }

    var body: some View {
        Button(action: select) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
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
                VStack(alignment: .trailing, spacing: 0) {
                    Text(Self.caption(option.kind))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(SleepNow.clock(option.time))
                        .font(.clock(18, weight: isSelected ? .regular : .light))
                        .monospacedDigit()
                        .foregroundStyle(isSelected ? .primary : .secondary)
                }
                Circle().fill(option.level.tint).frame(width: 8, height: 8)
                    .accessibilityHidden(true)
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

private extension View {
    /// Soft capsule look for buttons that share a List row (borderless keeps taps separate).
    func pill() -> some View {
        font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundStyle(Color.accentColor)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .background(Theme.cardFill, in: Capsule())
    }
}

private struct BulletLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            configuration.icon.font(.system(size: 4)).alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 3 }
            configuration.title
        }
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
            HStack(spacing: 10) {
                ForEach(legendKinds, id: \.self) { kind in
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2).fill(Self.color(kind)).frame(width: 10, height: 6)
                        Text(Self.name(kind))
                    }
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(segments.map { "\(Self.name($0.kind)) \(SleepNow.clock($0.start)) to \(SleepNow.clock($0.end))" }
            .joined(separator: ", "))
    }

    private var legendKinds: [SleepNow.Segment.Kind] {
        var seen: [SleepNow.Segment.Kind] = []
        for segment in segments where segment.kind != .awake && !seen.contains(segment.kind) { seen.append(segment.kind) }
        return seen
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
