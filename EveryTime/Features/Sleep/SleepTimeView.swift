import SwiftUI

/// One tap to sleep from now, with the alarm on a cycle end; asleep, ringing and just up take the page over.
/// Below, idle only: before bed, history and insights.
struct SleepTimeView: View {
    @Stored(JetLagKey.profile) private var storedProfile: JetLagProfile? = nil
    @Stored(NapKey.naps) private var storedNaps: [Nap] = []
    @Stored(NapKey.active) private var active: ActiveNap? = nil
    @AppStorage(PastNights.key) private var healthAsked = false
    @AppStorage("sleep.woke.dismissed") private var dismissedWoke = ""
    @AppStorage("sleep.morning.dismissed") private var dismissedMorning = ""
    @Environment(\.scenePhase) private var scenePhase
    @State private var health: [PastNight] = []
    @State private var healthLoadedAt: Date?
    /// A closed app can't wake you.
    @State private var alarmBlocked = false
    /// Bed and wake picked by chip, wheel or drag; they stay until they pass. nil = now / the pick for now.
    @Stored("sleep.plan.bed") private var storedBed: Date? = nil
    @Stored("sleep.plan.wake") private var storedWake: Date? = nil
    @AppStorage("sleep.kind") private var kind = SleepKind.sleep
    @AppStorage("sleep.nap.minutes") private var napMinutes = 20
    @State private var toast: UndoToast?
    @State private var sheet: SheetKind?
    @State private var editingNap: Nap?
    @State private var logDraft: LogDraft?

    private enum SheetKind: String, Identifiable {
        case profile
        var id: String { rawValue }
    }

    private struct LogDraft: Identifiable {
        var nap: Nap?
        let id = UUID()
    }

    private static let healthRefresh: TimeInterval = 15 * 60

    var body: some View {
        let cycle = SleepCycle.current
        TimelineView(NightSchedule(active: active)) { page(now: max($0.date, .now), cycle: cycle) }
            .animation(.snappy, value: active)
            .navigationTitle("Sleep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { InfoButton(label: "How this works", text: Self.howItWorks(cycle)) }
            }
            .task { await refresh() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await refresh() } }
            }
            .sheet(item: $sheet) { _ in
                JetLagProfileSheet(profile: storedProfile ?? JetLagProfile(), showsAdvice: false) {
                    storedProfile = $0
                    NotificationBudget.refresh()
                }
            }
            .sheet(item: $logDraft) { draft in
                LogNapSheet(draft: draft.nap) { log($0) }
            }
            .sheet(item: $editingNap) { nap in
                SleepEditor(nap: nap) { edited in
                    save(storedNaps.map { $0.id == edited.id ? edited : $0 })
                    NapSession.unrecord(nap)
                    NapSession.record(edited)
                } onDelete: {
                    delete(nap)
                }
            }
            .undoToast($toast)
            .sensoryFeedback(.impact(weight: .medium), trigger: active == nil)
    }

    private func page(now: Date, cycle: SleepCycle) -> some View {
        // Stored decodes on every read; read once per redraw.
        let profile = storedProfile ?? JetLagProfile()
        let naps = storedNaps
        return Group {
            if let active {
                NightScreen(phase: active.start > now ? .waiting(active)
                                : active.ringsAlarm && now >= active.alarm ? .ringing(active) : .asleep(active),
                            now: now, onCancel: cancel) {}
            } else if let woke = naps.first(where: { $0.isTracked && $0.energy == nil && $0.end <= now && now.timeIntervalSince($0.end) < 2 * 3600 }),
                      woke.id.uuidString != dismissedWoke {
                NightScreen(phase: .woke(woke), now: now, onCancel: { _ in }) { dismissedWoke = woke.id.uuidString }
            } else {
                idle(now: now, naps: naps, profile: profile, cycle: cycle)
            }
        }
    }

    // MARK: Idle

    private func idle(now: Date, naps: [Nap], profile: JetLagProfile, cycle: SleepCycle) -> some View {
        let advice = NapAdvice(profile: profile)
        let nights = PastNight.merged(logged: naps, health: health)
        let plan = SleepPlan.resolve(now: now, kind: kind, napMinutes: napMinutes, pickedBed: storedBed, pickedWake: storedWake,
                                     profile: profile, nights: nights)
        let choice = plan.choice
        // Until Health has answered, a night it holds would look missing.
        let healthReady = !healthAsked || healthLoadedAt != nil
        return ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 14) {
                    SleepHero(now: now, sleepNow: plan.sleepNow, choice: choice, bed: $storedBed, wake: $storedWake,
                              kind: Binding(get: { plan.kind }, set: { kind = $0 }), napMinutes: $napMinutes,
                              napBlockedTip: plan.napBlocked)
                    if alarmBlocked { alarmWarning }
                    if healthReady, let morning = MorningLog.proposal(now: now, naps: naps, health: health, advice: advice),
                       dismissedMorning != MorningLog.key(now) {
                        morningCard(morning)
                    }
                    usualHoursSuggestion(profile, nights: nights)
                }
                usualHours(profile)
                if plan.kind == .sleep, !choice.resleep, !choice.isNap, !choice.isNow {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel("Before bed")
                        CutoffLegend(bed: choice.bed, wake: choice.wake, now: now)
                    }
                }
                SleepHistory(nights: nights, naps: naps, now: now, need: SleepTrend.need(profile), advice: advice,
                             health: healthState, onLog: { logDraft = LogDraft() }, onEdit: { editingNap = $0 },
                             onDelete: delete, onAddHealth: addHealth)
                SleepInsights(nights: nights, naps: naps, profile: profile, cycle: cycle) { sheet = .profile }
            }
            .padding(.horizontal, Theme.padding)
            .padding(.vertical, 12)
        }
        .bottomBar {
            Button {
                if choice.isNow { NapSession.start(wake: choice.wake, resleep: choice.resleep) } else { NapSession.plan(bed: choice.bed, wake: choice.wake) }
            } label: {
                Label(choice.button, systemImage: choice.symbol)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .buttonStyle(.primary)
        }
    }

    /// No hours set yet: offer the ones read off past nights.
    @ViewBuilder
    private func usualHoursSuggestion(_ profile: JetLagProfile, nights: [PastNight]) -> some View {
        if storedProfile == nil, let usual = MorningLog.usualHours(from: nights) {
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
        }
    }

    private func usualHours(_ profile: JetLagProfile) -> some View {
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
        .accessibilityHint("Set your usual hours")
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
                Button("Edit…") { logDraft = LogDraft(nap: nap) }.buttonStyle(.soft)
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

    private var healthState: SleepHistory.HealthState {
        if !PastNights.isAvailable { return .unavailable }
        if !healthAsked { return .notAsked }
        guard healthLoadedAt != nil else { return .loading }
        return health.isEmpty ? .empty : .loaded
    }

    // MARK: Changes

    /// Every page-side write: sorted newest first, and the cycle relearned from it.
    private func save(_ naps: [Nap]) {
        let sorted = naps.sorted { $0.start > $1.start }
        storedNaps = sorted
        SleepCycle.relearn(from: sorted)
    }

    private func log(_ nap: Nap) {
        save(storedNaps + [nap])
        NapSession.record(nap)
        dismissedMorning = MorningLog.key(.now)
    }

    private func delete(_ nap: Nap) {
        save(storedNaps.filter { $0.id != nap.id })
        NapSession.unrecord(nap)
        toast = UndoToast(text: "Sleep deleted") { log(nap) }
    }

    /// Back to the page; the saved bed and wake times are never touched by starting or cancelling.
    private func cancel(_ nap: ActiveNap) {
        NapSession.cancel()
        let what = nap.start > .now ? "Plan" : nap.isNap ? "Nap" : "Sleep"
        withAnimation(.snappy) { toast = UndoToast(text: "\(what) cancelled") { NapSession.resume(nap) } }
    }

    private func addHealth() {
        Task {
            healthAsked = await PastNights.requestAccess()
            await refresh(force: true)
        }
    }

    /// Health nights and cycle, at most every 15 min unless forced; the alarm check every time.
    private func refresh(force: Bool = false) async {
        alarmBlocked = await NapAlarm.cannotRing
        guard healthAsked else { return }
        if !force, let at = healthLoadedAt, Date.now.timeIntervalSince(at) < Self.healthRefresh { return }
        health = await PastNights.load()
        var cycle = SleepCycle.current
        let estimate = await PastNights.cycleEstimate()
        cycle.healthMinutes = estimate?.minutes
        cycle.healthCount = estimate?.count ?? 0
        if cycle != SleepCycle.current { SleepCycle.current = cycle }
        healthLoadedAt = .now
    }

    private func clock(_ minutes: Int) -> String {
        SleepNow.clock(Calendar.current.clockTime(minutes: minutes, of: .now))
    }

    private static func howItWorks(_ cycle: SleepCycle) -> String { """
        A sleep cycle is about \(cycle.minutes) minutes, plus ~\(cycle.fallAsleepMinutes) to fall asleep; waking at a cycle's end feels easier. \
        Sleep now sets the alarm at the picked time; drag the ring or tap a chip to change it. \
        Chip dots: green 5–6 cycles or a short nap, orange 3–4, red 1–2. \
        The line above the ring: green wakes between cycles, orange in light sleep, red in deep sleep. \
        Before a night, "Before bed" counts down how long coffee and food are still fine: \
        coffee until \(Int(Caffeine.hoursBeforeBed)) h before bed (caffeine lasts ~5 h per half), \
        food until \(Int(LastMeal.hoursBeforeBed)) h before bed (late meals mean more night waking and higher \
        overnight blood sugar). A rough guide, not medical advice.
        """ }
}

/// Idle, and through long countdowns: every minute. The last hour before bed or the alarm: every second.
struct NightSchedule: TimelineSchedule {
    let marks: [Date]

    init(active: ActiveNap?) {
        marks = active.map { [$0.start] + ($0.ringsAlarm ? [$0.alarm] : []) } ?? []
    }

    func entries(from start: Date, mode: TimelineScheduleMode) -> AnyIterator<Date> {
        var next = start
        return AnyIterator {
            let current = next
            next = nextEntry(after: current)
            return current
        }
    }

    func nextEntry(after current: Date) -> Date {
        let upcoming = marks.filter { $0 > current }
        if upcoming.contains(where: { $0.timeIntervalSince(current) <= 3600 }) { return current.addingTimeInterval(1) }
        let minute = Date(timeIntervalSinceReferenceDate: ((current.timeIntervalSinceReferenceDate / 60).rounded(.down) + 1) * 60)
        let fast = upcoming.map { $0.addingTimeInterval(-3600) }.min()
        return fast.map { min($0, minute) } ?? minute
    }
}

#Preview {
    NavigationStack { SleepTimeView() }
}
