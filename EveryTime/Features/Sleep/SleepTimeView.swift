import SwiftUI

/// "When to sleep?": tonight's plan, what sleeping now would mean, and naps with a wake alarm.
struct SleepTimeView: View {
    @Stored(JetLagKey.profile) private var profile: JetLagProfile? = nil
    @Stored(NapKey.naps) private var naps: [Nap] = []
    @Stored(NapKey.active) private var active: ActiveNap? = nil
    @Stored(NapKey.night) private var plan: NightPlan? = nil
    @State private var offset = 0
    @State private var pickedNap: String?
    @State private var pickedSleep: String?
    @State private var showsAllNaps = false
    @State private var sheet: SheetKind?
    @State private var editsNight = false

    private enum SheetKind: String, Identifiable {
        case profile, log
        var id: String { rawValue }
    }

    private var advice: NapAdvice { NapAdvice(profile: profile ?? JetLagProfile(), plan: plan) }

    var body: some View {
        TimelineView(.everyMinute) { context in
            let now = context.date
            let day = advice.current(at: now)
            let napNow = SleepNow(advice: advice, start: now)
            let sleepNow = SleepNow(advice: advice, start: now.addingTimeInterval(Double(offset) * 60))
            ScrollViewReader { scroll in
                List {
                    if let active {
                        Section {
                            NapInProgress(nap: active, advice: advice)
                                .id(Self.napTop)
                                .listRowInsets(EdgeInsets(top: 8, leading: Theme.padding, bottom: 4, trailing: Theme.padding))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                            NapAlarmStatus().napRow()
                        }
                    }
                    Section {
                        tonightCard(day: day).napRow()
                    } header: {
                        SectionLabel(title: "Tonight") {
                            InfoButton(label: "About tonight", text: Self.tonightInfo)
                        }
                        .textCase(nil)
                    }
                    if active == nil {
                        // Whichever fits the time of day comes first.
                        if napNow.isDaytime {
                            napSection(napNow)
                            sleepSection(sleepNow)
                        } else {
                            sleepSection(sleepNow)
                            napSection(napNow)
                        }
                    }
                    if let nap = unratedNap(now: now) {
                        Section { ratePrompt(nap).napRow() } header: { SectionLabel("Last nap").textCase(nil) }
                    }
                    if naps.filter({ $0.night != nil }).count >= 3 {
                        Section { pattern.napRow() } header: { SectionLabel("Your nights after naps").textCase(nil) }
                    }
                    history
                    howItWorks
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .bottomBar { napControls }
                // A nap started from further down the page would leave its countdown off screen.
                .onChange(of: active?.start) { _, start in
                    guard start != nil else { return }
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(100))
                        withAnimation(.snappy) { scroll.scrollTo(Self.napTop, anchor: .top) }
                    }
                }
            }
        }
        .animation(.snappy, value: naps)
        .animation(.snappy, value: active)
        .animation(.snappy, value: pickedNap)
        .animation(.snappy, value: pickedSleep)
        .animation(.snappy, value: offset)
        .animation(.snappy, value: plan)
        .navigationTitle("When to sleep?")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $editsNight) {
            NightEditor(hours: nightBinding(day: advice.current(at: .now)), usual: usualHours)
        }
        .sheet(item: $sheet) { kind in
            switch kind {
            case .profile:
                JetLagProfileSheet(profile: profile ?? JetLagProfile(), showsAdvice: false) { profile = $0 }
            case .log:
                LogNapSheet { naps.insert($0, at: 0); naps.sort { $0.start > $1.start } }
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: active == nil)
        .sensoryFeedback(.selection, trigger: pickedNap)
        .sensoryFeedback(.selection, trigger: pickedSleep)
        .sensoryFeedback(.selection, trigger: offset)
    }

    // MARK: Tonight

    private func tonightCard(day: NapAdvice.Day) -> some View {
        let fit = SleepSuggestion.fit(minutesInBed: Int((day.nightHours * 60).rounded()))
        return Card {
            Button { editsNight = true } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .bottom, spacing: 10) {
                        clockColumn("Bed", symbol: "bed.double.fill", date: day.bed)
                        Image(systemName: "arrow.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .padding(.bottom, 8)
                        clockColumn("Wake up", symbol: "alarm.fill", date: day.nextWake)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .padding(.bottom, 10)
                    }
                    HStack(spacing: 10) {
                        Text("\(NapAdvice.hours(day.nightHours)) · \(fit.cycles) \(fit.cycles == 1 ? "cycle" : "cycles")")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        CycleFitLabel(isBetweenCycles: fit.isBetweenCycles)
                    }
                    .font(.subheadline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                }
                .foregroundStyle(.primary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Change tonight's bed and wake")
            if !fit.isBetweenCycles, let bed = cycleBed(near: day) {
                Button { nightBinding(day: day).wrappedValue.bed = bed } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "wand.and.stars")
                        Text("Bed at \(bed.timeOfDayText) wakes you between cycles")
                            .multilineTextAlignment(.leading)
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }
            if let note = advice.nightNote(on: day.wake) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "lightbulb")
                    Text(note)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            if plan(for: day) != nil {
                HStack {
                    Text("Changed for tonight")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Back to usual") {
                        plan = nil
                        pickedSleep = nil
                    }
                    .fontWeight(.semibold)
                }
                .font(.footnote)
            }
            Button { sheet = .profile } label: {
                LabeledContent {
                    HStack(spacing: 8) {
                        Text(profileSummary).monospacedDigit()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .foregroundStyle(.secondary)
                } label: {
                    infoLabel("Usual sleep", info: Self.usualInfo)
                }
                .font(.subheadline)
                .contentShape(Rectangle())
            }
            .tint(.primary)
        }
        .buttonStyle(.borderless)
    }

    private func clockColumn(_ title: String, symbol: String, date: Date) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                Text(title)
            }
            .font(.label)
                .foregroundStyle(.secondary)
            Text(SleepNow.clock(date))
                .font(.clock(28, weight: .regular))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())
        }
    }

    /// The 4–6-cycle bedtime for tonight's wake closest to the planned bed; ties go to the longer night.
    private func cycleBed(near day: NapAdvice.Day) -> Int? {
        let hours = nightBinding(day: day).wrappedValue
        let fallAsleep = Int(SleepSuggestion.fallAsleepTime / 60), cycle = Int(SleepSuggestion.cycleLength / 60)
        return [6, 5, 4]
            .map { NightDial.wrap(hours.wake - fallAsleep - $0 * cycle) }
            .min { NightDial.arc($0, hours.bed) < NightDial.arc($1, hours.bed) }
    }

    private var usualHours: NightDial.Hours {
        let usual = profile ?? JetLagProfile()
        return NightDial.Hours(bed: usual.usualBedtime, wake: usual.usualWake)
    }

    /// The plan for the night `day` leads into, if one is set.
    private func plan(for day: NapAdvice.Day) -> NightPlan? {
        plan.flatMap { Calendar.current.isDate($0.day, inSameDayAs: day.wake) ? $0 : nil }
    }

    /// Tonight's bed and wake, read fresh each time so a drag that moves both lands as one change.
    private func nightBinding(day: NapAdvice.Day) -> Binding<NightDial.Hours> {
        Binding {
            plan(for: day).map { NightDial.Hours(bed: $0.bed, wake: $0.wake) } ?? usualHours
        } set: { hours in
            plan = hours == usualHours ? nil
                : NightPlan(day: Calendar.current.startOfDay(for: day.wake), bed: hours.bed, wake: hours.wake)
        }
    }

    // MARK: Sleep now

    /// Going to bed for the night at now (or a little later): verdict, options, and what they do.
    private func sleepSection(_ sleepNow: SleepNow) -> some View {
        let options = sleepNow.sleepOptions
        let selected = Self.selection(in: options, picked: pickedSleep)
        return Section {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Menu {
                        Picker("When", selection: $offset) {
                            ForEach(SleepNow.offsets, id: \.self) { Text(Self.offsetText($0)).tag($0) }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(offset == 0 ? "If I sleep now" : "If I sleep \(Self.offsetText(offset).lowercased())")
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Image(systemName: "chevron.down.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        .font(.sectionTitle)
                        .foregroundStyle(.primary)
                    }
                    .tint(.primary)
                    .accessibilityLabel("When I'd sleep")
                    .accessibilityValue(Self.offsetText(offset))
                    Spacer()
                    InfoButton(label: "About sleeping now", text: Self.sleepInfo)
                }
                verdictText(sleepNow.sleepVerdict)
            }
            .buttonStyle(.borderless)
            .napRow()
            if !options.isEmpty {
                optionsCard(options, selected: selected, sleepNow: sleepNow) { pickedSleep = $0 == selected?.id ? Self.folded : $0 }.napRow()
            }
            if let selected, let action = sleepAction(selected, day: sleepNow.day) {
                action.napRow()
            }
            if let tip = sleepNow.tip {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "lightbulb")
                    Text(tip)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .napRow()
            }
        }
    }

    private static func offsetText(_ minutes: Int) -> String {
        minutes == 0 ? "Now" : minutes < 60 ? "In \(minutes) min" : "In \(minutes / 60) h"
    }

    /// Makes the picked option tonight's plan, unless it already is.
    private func sleepAction(_ option: SleepNow.Option, day: NapAdvice.Day) -> AnyView? {
        switch option.kind {
        case .bedAt(let bed) where !Calendar.current.isDate(bed, equalTo: day.bed, toGranularity: .minute):
            AnyView(Button { nightBinding(day: day).wrappedValue.bed = Self.minutes(of: bed) } label: {
                HStack(spacing: 8) { Image(systemName: "bed.double.fill"); Text("Use as tonight's bed") }
            }.buttonStyle(.soft))
        case .night(_, let wake) where !Calendar.current.isDate(wake, equalTo: day.nextWake, toGranularity: .minute):
            AnyView(Button { nightBinding(day: day).wrappedValue.wake = Self.minutes(of: wake) } label: {
                HStack(spacing: 8) { Image(systemName: "alarm.fill"); Text("Use as tomorrow's wake") }
            }.buttonStyle(.soft))
        default:
            nil
        }
    }

    private static func minutes(of date: Date) -> Int {
        Calendar.current.component(.hour, from: date) * 60 + Calendar.current.component(.minute, from: date)
    }

    // MARK: Nap now

    /// Napping right now: verdict, today's nap window, lengths and what each does, then start.
    private func napSection(_ napNow: SleepNow) -> some View {
        let options = napNow.napOptions
        let selected = Self.selection(in: options, picked: pickedNap)
        return Section {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text("If I nap now")
                        .font(.sectionTitle)
                    Spacer()
                    InfoButton(label: "About napping", text: Self.napInfo)
                }
                verdictText(napNow.napVerdict)
            }
            .napRow()
            NapWindowBar(day: napNow.day, window: napNow.window, now: napNow.start).napRow()
            optionsCard(options, selected: selected, sleepNow: napNow) { pickedNap = $0 == selected?.id ? Self.folded : $0 }.napRow()
            if case .nap(let minutes)? = selected?.kind {
                Button { NapSession.start(minutes: minutes) } label: {
                    Label("Start \(minutes)-min nap", systemImage: "alarm.fill")
                }
                .buttonStyle(.primary)
                .napRow()
            }
        }
    }

    private func verdictText(_ verdict: SleepNow.Verdict) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verdict.headline)
                .font(.system(.title3, design: .rounded, weight: .semibold))
            if !verdict.reason.isEmpty {
                Text(verdict.reason)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Options

    /// `picked` nil follows "Best"; `folded` means the open row was tapped shut.
    private static let folded = "folded"

    private static func selection(in options: [SleepNow.Option], picked: String?) -> SleepNow.Option? {
        picked == folded ? nil : options.first { $0.id == picked } ?? options.first(where: \.isRecommended)
    }

    /// One row per option; the picked one opens to show what it does until tomorrow's wake; tap it again to fold it.
    private func optionsCard(_ options: [SleepNow.Option], selected: SleepNow.Option?, sleepNow: SleepNow,
                             pick: @escaping (String) -> Void) -> some View {
        Card(padding: 6) {
            VStack(spacing: 2) {
                ForEach(options) { option in
                    let isSelected = option.id == selected?.id
                    VStack(alignment: .leading, spacing: 0) {
                        OptionRow(option: option, isSelected: isSelected) { pick(option.id) }
                        if isSelected {
                            optionDetail(option, sleepNow: sleepNow)
                                .padding(.leading, 40)
                                .padding(.trailing, 12)
                                .padding(.bottom, 14)
                                .transition(.opacity)
                        }
                    }
                    .background(isSelected ? Color.accentColor.opacity(0.08) : .clear,
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }

    private func optionDetail(_ option: SleepNow.Option, sleepNow: SleepNow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(effects(of: option, start: sleepNow.start), id: \.self) { effect in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: effect.symbol)
                        .foregroundStyle(effect.level.tint)
                        .frame(width: 20)
                    Text(effect.text)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            SleepTimeline(segments: sleepNow.segments(for: option), bed: sleepNow.day.bed)
                .padding(.top, 4)
        }
    }

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


    /// Only while napping.
    @ViewBuilder
    private var napControls: some View {
        if active != nil {
            HStack(spacing: Theme.spacing) {
                Button("Cancel nap") { NapSession.cancel() }
                    .buttonStyle(.soft)
                Button { NapSession.finish() } label: { Label("I'm up", systemImage: "sun.max.fill") }
                    .buttonStyle(.primary)
            }
        }
    }

    private func infoLabel(_ title: String, info: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
            InfoButton(label: "About \(title.lowercased())", text: info)
                .font(.footnote)
        }
    }

    private var profileSummary: String {
        guard let profile else { return "Not set" }
        return "\(profile.usualBedtime.timeOfDayText) – \(profile.usualWake.timeOfDayText)"
    }

    private static let sleepInfo = """
        Going to bed for the night now, or in a little while (tap the title). Pick an option to see \
        how it plays out until tomorrow's wake. \
        Green: little effect. Orange: some. Red: likely to hurt tonight's sleep or leave you groggy. \
        "Best" is the pick for right now.

        The bar: blue = nap, indigo = sleep, orange = slow to fall asleep, red = likely awake. \
        The line marks bedtime.
        """

    private static let tonightInfo = """
        Tap to change tonight's bed and wake on a dial. The change lasts one night; \
        the options below follow it.
        """

    private static let napInfo = """
        The bar runs from this morning's wake to tonight's bed. Blue is the nap window: the \
        post-lunch dip, from about 6 hours after you wake, ending early enough that a short nap \
        doesn't eat into tonight's sleep. The line is now.

        Green: little effect. Orange: some. Red: likely to hurt tonight's sleep or leave you groggy.
        The alarm rings even in silent mode.
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
        "Times include about 15 minutes to fall asleep.",
        "A nap ends with an alarm that rings even in silent mode, until you tap I'm up.",
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
            HStack {
                SectionLabel(title: "Naps") {
                    InfoButton(label: "About the nap log", text: Self.napsInfo)
                }
                napMenu
            }
            .textCase(nil)
        }
    }

    private var napMenu: some View {
        Menu {
            if active == nil {
                Menu("Start a nap", systemImage: "alarm") {
                    ForEach(NapAdvice.lengths, id: \.self) { minutes in
                        Button("\(minutes) min · wake at \(SleepNow.clock(.now.addingTimeInterval(Double(minutes) * 60)))") {
                            NapSession.start(minutes: minutes)
                        }
                    }
                }
            }
            Button("Add past nap", systemImage: "clock.arrow.circlepath") { sheet = .log }
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
        }
        .accessibilityLabel("Add a nap")
    }

    private static let recentNaps = 5
    private static let napTop = "napTop"
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
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .frame(width: 22)
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
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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

#Preview {
    NavigationStack { SleepTimeView() }
}

/// This morning's wake to tonight's bed, with the nap window and now marked.
private struct NapWindowBar: View {
    let day: NapAdvice.Day
    let window: DateInterval
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Nap window")
                Spacer()
                Text("\(SleepNow.clock(window.start)) – \(SleepNow.clock(window.end))")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            GeometryReader { geo in
                let span = max(1, day.bed.timeIntervalSince(day.wake))
                let x = { (date: Date) in geo.size.width * min(1, max(0, date.timeIntervalSince(day.wake) / span)) }
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.1))
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: max(4, x(window.end) - x(window.start)))
                        .offset(x: x(window.start))
                    if now > day.wake && now < day.bed {
                        Capsule()
                            .fill(Color.primary)
                            .frame(width: 3, height: 16)
                            .offset(x: x(now) - 1.5)
                    }
                }
                .frame(height: 16)
                .frame(maxHeight: .infinity)
            }
            .frame(height: 16)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Nap window \(SleepNow.clock(window.start)) to \(SleepNow.clock(window.end))")
    }
}

private extension Font {
    static let sectionTitle = Font.system(.title, design: .rounded, weight: .bold)
}
