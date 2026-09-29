import SwiftUI

/// "When to sleep?": one answer for right now, tonight's plan, and the nap log.
struct SleepTimeView: View {
    @Stored(JetLagKey.profile) private var profile: JetLagProfile? = nil
    @Stored(NapKey.naps) private var naps: [Nap] = []
    @Stored(NapKey.active) private var active: ActiveNap? = nil
    @Stored(NapKey.night) private var plan: NightPlan? = nil
    @Stored(ActivityLog.key) private var activityMarks: [ActivityMark] = []
    @State private var picked: String?
    @State private var showsAllNaps = false
    @State private var sheet: SheetKind?
    @State private var editsNight = false

    private enum SheetKind: String, Identifiable {
        case profile, log, info
        var id: String { rawValue }
    }

    private var advice: NapAdvice { NapAdvice(profile: profile ?? JetLagProfile(), plan: plan) }
    private var activityLog: ActivityLog { ActivityLog(marks: activityMarks) }

    var body: some View {
        TimelineView(.everyMinute) { context in
            let now = context.date
            let day = advice.current(at: now)
            ScrollViewReader { scroll in
                List {
                    Section {
                        if let active {
                            NapInProgress(nap: active, advice: advice)
                                .id(Self.top)
                                .listRowInsets(EdgeInsets(top: 8, leading: Theme.padding, bottom: 4, trailing: Theme.padding))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                            NapAlarmStatus().napRow()
                        } else {
                            answerCard(SleepNow(advice: advice, start: now)).id(Self.top).napRow()
                        }
                    }
                    Section {
                        tonightCard(day: day).napRow()
                    } header: {
                        SectionLabel("Tonight").textCase(nil)
                    }
                    if LoggedDayCard.hasContent(activityLog, now: now) {
                        Section {
                            LoggedDayCard(log: activityLog, now: now).napRow()
                        } header: {
                            SectionLabel("From What did").textCase(nil)
                        }
                    }
                    if let nap = unratedNap(now: now) {
                        Section { ratePrompt(nap).napRow() } header: { SectionLabel("Last nap").textCase(nil) }
                    }
                    PastNightsSection()
                    history
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .bottomBar { napControls }
                // A nap started from further down the page would leave its countdown off screen.
                .onChange(of: active?.start) { _, start in
                    guard start != nil else { return }
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(100))
                        withAnimation(.snappy) { scroll.scrollTo(Self.top, anchor: .top) }
                    }
                }
            }
        }
        .animation(.snappy, value: naps)
        .animation(.snappy, value: active)
        .animation(.snappy, value: picked)
        .animation(.snappy, value: plan)
        .navigationTitle("When to sleep?")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { sheet = .info } label: { Image(systemName: "info.circle") }
                    .accessibilityLabel("How this works")
            }
        }
        .navigationDestination(isPresented: $editsNight) {
            NightEditor(hours: nightBinding(day: advice.current(at: .now)), usual: usualHours) { sheet = .profile }
        }
        .sheet(item: $sheet) { kind in
            switch kind {
            case .profile:
                JetLagProfileSheet(profile: profile ?? JetLagProfile(), showsAdvice: false) { profile = $0 }
            case .log:
                LogNapSheet { naps.insert($0, at: 0); naps.sort { $0.start > $1.start } }
            case .info:
                HowSleepWorksSheet()
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: active == nil)
        .sensoryFeedback(.selection, trigger: picked)
    }

    // MARK: Answer

    /// The verdict for now, the picked option and its one action, then the other options as chips.
    private func answerCard(_ now: SleepNow) -> some View {
        let options = now.options
        let selected = options.first { $0.id == picked } ?? options.first(where: \.isRecommended) ?? options.first
        return Card {
            VStack(alignment: .leading, spacing: 4) {
                Text(now.verdict.headline)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                if !now.verdict.reason.isEmpty {
                    Text(now.verdict.reason)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let selected {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selected.caption)
                        .font(.label)
                        .foregroundStyle(.secondary)
                    Text(SleepNow.clock(selected.time))
                        .font(.clock(34, weight: .regular))
                        .contentTransition(.numericText())
                }
                .padding(.top, 4)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(effects(of: selected, start: now.start), id: \.self) { effect in
                        NapEffectRow(symbol: effect.symbol, text: effect.text, level: effect.level)
                    }
                }
                action(for: selected, day: now.day)
                if options.count > 1 {
                    FlowLayout(spacing: 8) {
                        ForEach(options) { option in
                            OptionChip(option: option, isOn: option.id == selected.id) { picked = option.id }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            if let tip = now.tip {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "lightbulb")
                    Text(tip)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func action(for option: SleepNow.Option, day: NapAdvice.Day) -> some View {
        switch option.kind {
        case .nap(let minutes):
            Button { NapSession.start(minutes: minutes) } label: {
                Label("Start \(minutes)-min nap", systemImage: "alarm.fill")
            }
            .buttonStyle(.primary)
        case .bedAt(let bed) where !Calendar.current.isDate(bed, equalTo: day.bed, toGranularity: .minute):
            Button { nightBinding(day: day).wrappedValue.bed = Self.minutes(of: bed) } label: {
                Label("Make \(SleepNow.clock(bed)) tonight's bed", systemImage: "bed.double.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.soft)
        case .night(_, let wake) where !Calendar.current.isDate(wake, equalTo: day.nextWake, toGranularity: .minute):
            Button { nightBinding(day: day).wrappedValue.wake = Self.minutes(of: wake) } label: {
                Label("Make \(SleepNow.clock(wake)) tomorrow's wake", systemImage: "alarm.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.soft)
        default:
            EmptyView()
        }
    }

    private func effects(of option: SleepNow.Option, start: Date) -> [Effect] {
        switch option.kind {
        case .nap(let minutes):
            let tonight = advice.tonight(start: start, minutes: minutes, bed: advice.current(at: start).bed)
            return [Effect(symbol: "moon.zzz", text: NapAdvice.tonightText(tonight), level: tonight),
                    Effect(symbol: "sun.max", text: NapAdvice.wakeText(minutes: minutes), level: NapAdvice.grogginess(minutes: minutes))]
        case .bedAt:
            return [Effect(symbol: "bed.double", text: option.detail, level: option.level)]
        case .splitNight:
            return [Effect(symbol: "exclamationmark.triangle", text: option.detail, level: option.level)]
        case .night:
            return [Effect(symbol: "alarm", text: option.detail, level: option.level)]
        }
    }

    private struct Effect: Hashable {
        let symbol: String
        let text: String
        let level: NapAdvice.Level
    }

    private static func minutes(of date: Date) -> Int {
        Calendar.current.component(.hour, from: date) * 60 + Calendar.current.component(.minute, from: date)
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
                    if plan(for: day) != nil {
                        Text("Changed for tonight")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Change tonight's bed and wake")
            if profile == nil {
                Button { sheet = .profile } label: {
                    Label("Set your usual sleep hours", systemImage: "person.crop.circle")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderless)
            }
        }
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
            if naps.filter({ $0.night != nil }).count >= 3 {
                pattern.napRow()
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
                SectionLabel("Naps")
                Button { sheet = .log } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                }
                .accessibilityLabel("Add past nap")
            }
            .textCase(nil)
        }
    }

    private static let recentNaps = 5
    private static let top = "top"
}

/// One way to sleep from now; the dot is its effect on tonight.
private struct OptionChip: View {
    let option: SleepNow.Option
    let isOn: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: 6) {
                Circle().fill(option.level.tint).frame(width: 7, height: 7)
                Text(option.title)
                    .font(.system(.subheadline, design: .rounded, weight: isOn ? .semibold : .regular))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 36)
            .foregroundStyle(isOn ? Color.white : .primary)
            .background(isOn ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.primary.opacity(0.08)), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityValue(option.isRecommended ? "Best" : "")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

private struct HowSleepWorksSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Self.lines, id: \.self) { line in
                        Label(line, systemImage: "circle.fill")
                            .labelStyle(BulletLabelStyle())
                    }
                    Text(NapAdvice.info)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .screen()
                .padding(.vertical, 12)
            }
            .navigationTitle("How this works")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }

    private static let lines = [
        "The top card answers for right now: a nap by day, bed or wake times from evening. Tap another chip to compare.",
        "Green: little effect on tonight. Orange: some. Red: likely to hurt tonight's sleep or leave you groggy.",
        "A sleep cycle is about 90 minutes. Waking between cycles feels easier; 5–6 cycles is a full night.",
        "Times include about 15 minutes to fall asleep.",
        "The nap window is the post-lunch dip, from about 6 hours after you wake, ending early enough not to eat into tonight.",
        "Tonight's bed and wake come from your usual hours; tap Tonight to change them for one night.",
        "A nap ends with an alarm that rings even in silent mode, until you tap I'm up.",
        "Rate how each night went after a nap; after 3 ratings you'll see whether the advice matches you.",
    ]
}

private struct BulletLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            configuration.icon.font(.system(size: 4)).alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 3 }
            configuration.title
        }
    }
}

#Preview {
    NavigationStack { SleepTimeView() }
}
