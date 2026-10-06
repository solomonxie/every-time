import SwiftUI

/// One tap to sleep from now, with the alarm on a cycle end; asleep, ringing and just up take the page over.
/// Below, idle only: today's coffee, energy and sleep debt, then trends, nights and naps.
struct SleepTimeView: View {
    @Stored(JetLagKey.profile) private var storedProfile: JetLagProfile? = nil
    @Stored(NapKey.naps) private var storedNaps: [Nap] = []
    @Stored(NapKey.active) private var active: ActiveNap? = nil
    @AppStorage(PastNights.key) private var healthAsked = false
    @AppStorage("sleep.woke.dismissed") private var dismissedWoke = ""
    @AppStorage("sleep.morning.dismissed") private var dismissedMorning = ""
    @State private var health: [PastNight] = []
    @State private var healthLoaded = false
    /// Pre-iOS 26: a closed app can't ring without notifications.
    @State private var alarmBlocked = false
    /// Bed and wake picked by chip, wheel or drag; they stay until they pass. nil = now / the pick for now.
    @Stored("sleep.plan.bed") private var storedBed: Date? = nil
    @Stored("sleep.plan.wake") private var storedWake: Date? = nil
    @AppStorage("sleep.kind") private var kind = SleepKind.nap
    @AppStorage("sleep.nap.minutes") private var napMinutes = 20
    @State private var toast: Toast?
    @State private var showsAllHistory = false
    @State private var sheet: SheetKind?
    @State private var editingNap: Nap?

    private enum SheetKind: String, Identifiable {
        case profile, log
        var id: String { rawValue }
    }

    private struct Toast: Equatable {
        let text: String
        let undo: (() -> Void)?
        let id = UUID()
        static func == (a: Toast, b: Toast) -> Bool { a.id == b.id }
    }

    var body: some View {
        Group {
            // The night screen counts seconds; the idle page only needs the minute.
            if active != nil {
                TimelineView(.periodic(from: .now, by: 1)) { page(now: max($0.date, .now)) }
            } else {
                TimelineView(.everyMinute) { page(now: max($0.date, .now)) }
            }
        }
        .animation(.snappy, value: active)
        .animation(.snappy, value: storedNaps.count)
        .navigationTitle("Sleep")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { InfoButton(label: "How this works", text: Self.howItWorks) }
        }
        .task {
            SleepCycle.relearn(from: storedNaps)
            await loadHealth()
            if NapAlarm.kind == .app { alarmBlocked = await NapAlarm.notificationsDenied }
        }
        .onChange(of: storedNaps) { SleepCycle.relearn(from: storedNaps) }
        .sheet(item: $sheet) { kind in
            switch kind {
            case .profile:
                JetLagProfileSheet(profile: storedProfile ?? JetLagProfile(), showsAdvice: false) { storedProfile = $0 }
            case .log:
                LogNapSheet { log($0) }
            }
        }
        .sheet(item: $editingNap) { nap in
            SleepEditor(nap: nap) { edited in
                storedNaps = storedNaps.map { $0.id == edited.id ? edited : $0 }.sorted { $0.start > $1.start }
                ActivityLog.remove(.sleep, at: nap.start)
                ActivityLog.remove(nil, at: nap.end)
                ActivityLog.record(.sleep, at: edited.start)
                ActivityLog.record(nil, at: edited.end)
            } onDelete: {
                delete(nap)
            }
        }
        .overlay(alignment: .bottom) { toastView }
        .sensoryFeedback(.impact(weight: .medium), trigger: active == nil)
    }

    private func page(now: Date) -> some View {
        // Stored decodes on every read; read once per redraw.
        let profile = storedProfile ?? JetLagProfile()
        let naps = storedNaps
        return Group {
            if let active {
                NightScreen(phase: active.start > now ? .waiting(active)
                                : active.ringsAlarm && now >= active.alarm ? .ringing(active) : .asleep(active),
                            now: now, onCancel: cancel) {}
            } else if let woke = naps.first(where: { $0.energy == nil && $0.end <= now && now.timeIntervalSince($0.end) < 2 * 3600 }),
                      woke.id.uuidString != dismissedWoke {
                NightScreen(phase: .woke(woke), now: now, onCancel: { _ in }) { dismissedWoke = woke.id.uuidString }
            } else {
                idle(now: now, naps: naps, profile: profile)
            }
        }
    }

    // MARK: Idle

    private func napTip(_ profile: JetLagProfile, now: Date, slept: Bool) -> String? {
        let c = Calendar.current.dateComponents([.hour, .minute], from: now)
        let minute = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        let (bed, wake) = (profile.usualBedtime, profile.usualWake)
        let from = (bed - 60 + 24 * 60) % (24 * 60)
        let nearBed = from <= bed ? (from..<bed).contains(minute) : (minute >= from || minute < bed)
        let inNight = bed <= wake ? (bed...wake).contains(minute) : (minute >= bed || minute <= wake)
        guard nearBed || (inNight && !slept) else { return nil }
        return "It's within an hour of, or inside, your usual sleep hours (\(bed.timeOfDayText) – \(wake.timeOfDayText)). Use Sleep instead."
    }

    private func idle(now: Date, naps: [Nap], profile: JetLagProfile) -> some View {
        let advice = NapAdvice(profile: profile)
        // Sleep times sit on the ring's 10-minute marks, so "now" is the nearest mark.
        let nights = PastNight.merged(logged: naps, health: health)
        let slept = nights.contains { $0.end <= now && now.timeIntervalSince($0.end) < 14 * 3600 && $0.end.timeIntervalSince($0.start) >= Nap.nightLength }
        let tonight = Calendar.current.nextDate(after: now, matching: DateComponents(hour: profile.usualBedtime / 60, minute: profile.usualBedtime % 60), matchingPolicy: .nextTime)
        let bed = kind == .nap ? now : SleepRing.snap(storedBed.flatMap { $0.timeIntervalSince(now) >= 60 ? $0 : nil } ?? (slept ? tonight : nil) ?? now)
        let sleepNow = SleepNow(advice: advice, start: bed)
        let long = sleepNow.pick.map { SleepRing.snap($0.time) }.flatMap { $0.timeIntervalSince(bed) >= Nap.nightLength ? $0 : nil }
        let wake = kind == .nap ? bed.addingTimeInterval(Double(napMinutes) * 60)
            : SleepRing.snap(storedWake.flatMap { $0.timeIntervalSince(bed) >= Nap.nightLength - 60 ? $0 : nil }
                ?? long ?? bed.addingTimeInterval(8 * 3600))
        let choice = WakeChoice(now: now, bed: bed, wake: wake)
        return ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 14) {
                    SleepHero(now: now, sleepNow: sleepNow, choice: choice, bed: $storedBed, wake: $storedWake,
                              kind: $kind, napMinutes: $napMinutes, napBlockedTip: napTip(profile, now: now, slept: slept))
                    if alarmBlocked { alarmWarning }
                    if let morning = MorningLog.proposal(now: now, naps: naps, health: health, advice: advice),
                       dismissedMorning != MorningLog.key(now) {
                        morningCard(morning)
                    }
                    hoursLine(profile, nights: nights)
                }
                schedule(profile)
                history(nights: nights, naps: naps, now: now, profile: profile, advice: advice)
                insights(nights: nights, naps: naps, profile: profile)
            }
            .padding(.horizontal, Theme.padding)
            .padding(.vertical, 12)
        }
        .bottomBar {
            Button {
                if choice.isNow { NapSession.start(wake: choice.wake) } else { NapSession.plan(bed: choice.bed, wake: choice.wake) }
            } label: {
                Label(choice.button, systemImage: choice.symbol)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .buttonStyle(.primary)
        }
    }

    @ViewBuilder
    private func hoursLine(_ profile: JetLagProfile, nights: [PastNight]) -> some View {
        if storedProfile == nil {
            if let usual = MorningLog.usualHours(from: nights) {
                Button {
                    var p = profile
                    p.usualBedtime = usual.bed
                    p.usualWake = usual.wake
                    storedProfile = p
                } label: {
                    Label("Use \(clock(usual.bed)) – \(clock(usual.wake)) from your last nights", systemImage: "heart.text.square")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderless)
            } else {
                Button { sheet = .profile } label: {
                    Label("Usually \(clock(profile.usualBedtime)) – \(clock(profile.usualWake)) · Set your hours", systemImage: "person.crop.circle")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func morningCard(_ nap: Nap) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Did you sleep last night?").font(.cardTitle)
            HStack(spacing: 10) {
                Button {
                    log(nap)
                } label: {
                    Label("Yes · \(SleepNow.clock(nap.start)) – \(SleepNow.clock(nap.end))", systemImage: "checkmark")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .foregroundStyle(.white)
                        .background(Color.indigo, in: Capsule())
                }
                .buttonStyle(.plain)
                Button("Edit…") { sheet = .log }.buttonStyle(.soft)
                Button("No") { dismissedMorning = MorningLog.key(.now) }.buttonStyle(.soft)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var alarmWarning: some View {
        HStack(spacing: 8) {
            Label("Alarm can't ring — notifications are off", systemImage: "bell.slash.fill")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Theme.Tone.warn)
            Spacer()
            Button("Turn on") {
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(url) }
            }
            .font(.footnote.weight(.semibold))
        }
    }

    private func log(_ nap: Nap) {
        storedNaps = (storedNaps + [nap]).sorted { $0.start > $1.start }
        dismissedMorning = MorningLog.key(.now)
    }

    /// Back to the page; the saved bed and wake times are never touched by starting or cancelling.
    private func cancel(_ nap: ActiveNap) {
        NapSession.cancel()
        let what = nap.start > .now ? "Plan" : Double(nap.minutes) * 60 < Nap.nightLength ? "Nap" : "Sleep"
        show(Toast(text: "\(what) cancelled") { NapSession.resume(nap) })
    }

    private func clock(_ minutes: Int) -> String {
        SleepNow.clock(Calendar.current.clockTime(minutes: minutes, of: .now))
    }

    // MARK: Toast

    private func show(_ toast: Toast) {
        withAnimation(.snappy) { self.toast = toast }
    }

    @ViewBuilder
    private var toastView: some View {
        if let toast {
            HStack(spacing: 14) {
                Text(toast.text).font(.label)
                if let undo = toast.undo {
                    Button("Undo") { undo(); withAnimation(.snappy) { self.toast = nil } }
                        .font(.label.weight(.bold))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
            .padding(.bottom, 80)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .task(id: toast) {
                try? await Task.sleep(for: .seconds(4))
                guard !Task.isCancelled else { return }
                withAnimation(.snappy) { self.toast = nil }
            }
        }
    }

    // MARK: Insights

    /// Sleep debt and energy at a glance, then the trend chart.
    private func insights(nights: [PastNight], naps: [Nap], profile: JetLagProfile) -> some View {
        let debt = SleepTrend.debt(nights, usualHours: profile.sleepHours)
        let energy = EnergyChart.mean(naps)
        let streak = SleepTrend.wakeStreak(nights, usualWake: profile.usualWake)
        let cycle = SleepCycle.current
        return VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Insights")
            VStack(alignment: .leading, spacing: 14) {
                Button { sheet = .profile } label: {
                    insightRow("arrow.triangle.2.circlepath", "Cycle length", value: "\(cycle.minutes) min",
                               tint: .indigo, detail: cycle.sourceText.prefix(1).uppercased() + cycle.sourceText.dropFirst(), info: Self.cycleInfo)
                }
                .buttonStyle(.plain)
                if !nights.isEmpty {
                    insightRow("bed.double.fill", "Sleep debt",
                               value: debt < 15 * 60 ? "None" : ActivityLog.duration(debt),
                               tint: debt >= 3 * 3600 ? Theme.Tone.bad : debt >= 3600 ? Theme.Tone.warn : Theme.Tone.good,
                               detail: "Short of \(Int(profile.sleepHours)) h/night over the last 7", info: Self.debtInfo(streak: streak))
                }
                if let energy {
                    insightRow("bolt.fill", "Energy",
                               value: energy.formatted(.number.precision(.fractionLength(1))) + " / 5",
                               tint: EnergyChart.tint(Int(energy.rounded())),
                               detail: "How you felt waking, recently", info: Self.energyInfo)
                }
                if nights.count >= 2 {
                    Text("Sleep score").font(.label).foregroundStyle(.secondary)
                    ScoreChart(nights: nights, usualHours: profile.sleepHours).frame(height: 100)
                }
                if EnergyChart.rated(naps).count >= 2 {
                    Text("Energy on waking").font(.label).foregroundStyle(.secondary)
                    EnergyChart(naps: naps).frame(height: 100)
                }
            }
            .padding(14)
            .background(Theme.cardFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func insightRow(_ symbol: String, _ title: String, value: String, tint: Color, detail: String, info: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(tint).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title).font(.subheadline.weight(.semibold))
                    InfoButton(label: "About \(title.lowercased())", text: info)
                }
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(value).font(.clock(20, weight: .semibold)).foregroundStyle(tint)
        }
    }

    // MARK: History

    /// Every sleep, nights and naps together, newest first; tap a logged one to edit it.
    private enum Entry: Identifiable {
        case night(PastNight), nap(Nap)
        var id: String { switch self { case .night(let n): "n\(n.id.timeIntervalSinceReferenceDate)"; case .nap(let n): n.id.uuidString } }
        var start: Date { switch self { case .night(let n): n.start; case .nap(let n): n.start } }
    }

    private func history(nights: [PastNight], naps: [Nap], now: Date, profile: JetLagProfile, advice: NapAdvice) -> some View {
        let short = naps.filter { !$0.isNight }
        let entries = (nights.map(Entry.night) + short.map(Entry.nap)).sorted { $0.start > $1.start }
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel(title: "History") { InfoButton(label: "About history", text: Self.nightsInfo) }
                Spacer()
                Button { sheet = .log } label: { Image(systemName: "plus.circle.fill").font(.title3) }
                    .accessibilityLabel("Log past sleep")
            }
            if entries.isEmpty {
                Text("Nights and naps you sleep from here show up with a score.").font(.subheadline).foregroundStyle(.secondary)
            }
            if let nap = short.first(where: { $0.night == nil && !Calendar.current.isDate($0.start, inSameDayAs: now)
                && now.timeIntervalSince($0.start) < 3 * 86_400 }) {
                ratePrompt(nap)
            }
            ForEach(showsAllHistory ? entries : Array(entries.prefix(5))) { entry in
                switch entry {
                case .night(let night):
                    let own = night.source.flatMap { id in storedNaps.first { $0.id == id } }
                    PastNightRow(night: night, usualHours: profile.sleepHours)
                        .contentShape(Rectangle())
                        .onTapGesture { if let own { editingNap = own } }
                        .contextMenu {
                            if let own {
                                Button("Edit", systemImage: "slider.horizontal.3") { editingNap = own }
                                Button("Delete", systemImage: "trash", role: .destructive) { delete(own) }
                            } else {
                                Text("From Health")
                            }
                        }
                case .nap(let nap):
                    NapRow(nap: nap, level: advice.tonight(start: nap.start, minutes: nap.minutes, bed: nap.bed))
                        .contentShape(Rectangle())
                        .onTapGesture { editingNap = nap }
                        .contextMenu {
                            Button("Edit", systemImage: "slider.horizontal.3") { editingNap = nap }
                            ForEach(Nap.Night.allCases) { night in
                                Button(night.title, systemImage: night.symbol) { rate(nap, night) }
                            }
                            Button("Delete", systemImage: "trash", role: .destructive) { delete(nap) }
                        }
                }
            }
            if entries.count > 5 {
                Button(showsAllHistory ? "Show less" : "Show all \(entries.count)") { showsAllHistory.toggle() }.font(.label)
            }
            if PastNights.isAvailable, !healthAsked {
                Button {
                    Task {
                        healthAsked = await PastNights.requestAccess()
                        await loadHealth()
                    }
                } label: {
                    Label("Add nights from Health", systemImage: "heart.text.square").font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderless)
            } else if healthAsked, healthLoaded, health.isEmpty {
                Text("No sleep in Health for the last two weeks. Check Settings › Health › Data Access › Every Time.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private func loadHealth() async {
        guard healthAsked else { return }
        health = await PastNights.load()
        var cycle = SleepCycle.current
        let estimate = await PastNights.cycleEstimate()
        cycle.healthMinutes = estimate?.minutes
        cycle.healthCount = estimate?.count ?? 0
        if cycle != SleepCycle.current { SleepCycle.current = cycle }
        healthLoaded = true
    }

    private func ratePrompt(_ nap: Nap) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How was the night after \(nap.start.formatted(.dateTime.weekday(.wide)))'s \(nap.minutes)-min nap?")
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

    private func delete(_ nap: Nap) {
        storedNaps.removeAll { $0.id == nap.id }
        ActivityLog.remove(.sleep, at: nap.start)
        ActivityLog.remove(nil, at: nap.end)
    }

    private func rate(_ nap: Nap, _ night: Nap.Night?) {
        var naps = storedNaps
        guard let i = naps.firstIndex(where: { $0.id == nap.id }) else { return }
        naps[i].night = night
        storedNaps = naps
    }

    // MARK: Usual hours

    private func schedule(_ profile: JetLagProfile) -> some View {
        let cycle = SleepCycle.current
        return VStack(alignment: .leading, spacing: 8) {
            Button { sheet = .profile } label: {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle").foregroundStyle(.indigo).frame(width: 22)
                    Text("Usually \(clock(profile.usualBedtime)) – \(clock(profile.usualWake))")
                        .font(.subheadline.weight(.semibold)).monospacedDigit()
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
                }
                .padding(14)
                .background(Theme.cardFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            Text("Cycle \(cycle.minutes) min · \(cycle.sourceText)")
                .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 14)
        }
    }

    private static var howItWorks: String { """
        A sleep cycle is about \(SleepCycle.current.minutes) minutes, plus ~\(SleepCycle.current.fallAsleepMinutes) to fall asleep; waking at a cycle's end feels easier. \
        Sleep now sets the alarm at the picked time; drag the ring or tap a chip to change it. \
        Green: 5–6 cycles or a short nap. Orange: 3–4. Red: 1–2. Coffee cutoff is 8 h before your usual bed; \
        under 90 min since the last cup is too soon. A rough guide, not medical advice.
        """ }

    private static let cycleInfo = """
        How long one sleep cycle runs for you. Each time you wake before the alarm the app notes how long \
        you slept; after three such wakes it picks the length (70–120 min) that lands them on cycle ends, \
        and the ring, chips and "wakes between cycles" use it. Tap to set it yourself instead.
        """

    private static let energyInfo = """
        How rested you've been. After each sleep or nap, rate how you feel; this averages your recent ratings.
        Low? Try waking at a cycle's end or a shorter nap. The Energy trend shows which sleeps worked.
        """

    private static func debtInfo(streak: Int) -> String {
        """
        Hours you slept under your usual amount over the last 7 nights. Under 1 h is fine; 3 h+ is worth catching up.
        Pay it back with an earlier bedtime or a nap, not a long lie-in — waking at a steady time helps most \
        (\(streak) \(streak == 1 ? "day" : "days") in a row so far).
        """
    }

    private static let nightsInfo = """
        Nights and naps slept from here, plus the Health app's nights on days with nothing logged. A sleep \
        shorter than one cycle is a nap. Score 0–100: up to 60 for \
        length against your usual hours, 20 for waking between cycles, 20 for how you felt. Sleep debt: hours \
        short of your usual over the last 7 nights. Steady wake: nights in a row up within 30 min of your usual time.
        """
}

/// The morning after a night the app didn't see: what to log, and usual hours read off past nights.
enum MorningLog {
    /// Last night at the usual hours; only in the first hours after the usual wake when neither the app nor Health saw a night.
    static func proposal(now: Date, naps: [Nap], health: [PastNight], advice: NapAdvice, calendar: Calendar = .current) -> Nap? {
        let day = advice.day(of: now)
        guard now >= day.wake, now < day.wake.addingTimeInterval(5 * 3600) else { return nil }
        guard !naps.contains(where: { $0.isNight && now.timeIntervalSince($0.end) < 14 * 3600 }),
              !health.contains(where: { calendar.isDate($0.end, inSameDayAs: now) })
        else { return nil }
        let bed = advice.day(of: calendar.date(byAdding: .day, value: -1, to: now) ?? now).bed
        return Nap(start: bed, end: day.wake)
    }

    static func key(_ date: Date, calendar: Calendar = .current) -> String {
        calendar.startOfDay(for: date).formatted(.iso8601.year().month().day())
    }

    /// Median bed and wake, as minutes after midnight, once there are a week of nights.
    static func usualHours(from nights: [PastNight], calendar: Calendar = .current) -> (bed: Int, wake: Int)? {
        guard nights.count >= 7 else { return nil }
        func minutes(_ date: Date) -> Int {
            let c = calendar.dateComponents([.hour, .minute], from: date)
            return (c.hour ?? 0) * 60 + (c.minute ?? 0)
        }
        // Bedtimes straddle midnight: measure them from noon so the median isn't split.
        let beds = nights.map { (minutes($0.start) + 12 * 60) % (24 * 60) }.sorted()
        let wakes = nights.map { minutes($0.end) }.sorted()
        let round = { (m: Int) in (m + 2) / 5 * 5 }
        return (bed: round((beds[beds.count / 2] + 12 * 60) % (24 * 60)), wake: round(wakes[wakes.count / 2]))
    }
}

#Preview {
    NavigationStack { SleepTimeView() }
}
