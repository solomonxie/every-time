import SwiftUI

/// Decide one end of the night and get the other; while asleep, the cycle you're in; on waking, how you feel.
/// Below: today's coffee, energy and sleep debt, then trends, nights and naps.
struct SleepTimeView: View {
    @Stored(JetLagKey.profile) private var storedProfile: JetLagProfile? = nil
    @Stored(NapKey.naps) private var storedNaps: [Nap] = []
    @Stored(NapKey.active) private var active: ActiveNap? = nil
    @AppStorage(PastNights.key) private var healthAsked = false
    @State private var health: [PastNight] = []
    @State private var healthLoaded = false
    @State private var trend = Trend.score
    @State private var showsAllNights = false
    @State private var showsAllNaps = false
    @State private var sheet: SheetKind?

    private enum Trend: String, CaseIterable { case score = "Sleep score", energy = "Energy" }

    private enum SheetKind: String, Identifiable {
        case profile, log
        var id: String { rawValue }
    }

    var body: some View {
        TimelineView(.everyMinute) { context in
            let now = max(context.date, .now)
            // Stored decodes on every read; read once per redraw.
            let profile = storedProfile ?? JetLagProfile()
            let naps = storedNaps
            let advice = NapAdvice(profile: profile)
            let nights = PastNight.merged(logged: naps, health: health)
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    hero(now: now, naps: naps, profile: profile)
                    if active == nil {
                        today(now: now, naps: naps, nights: nights, profile: profile, advice: advice)
                    }
                    if nights.count >= 2 || EnergyChart.rated(naps).count >= 2 {
                        trends(nights: nights, naps: naps, profile: profile)
                    }
                    nightsSection(nights, profile: profile)
                    napsSection(naps, now: now, advice: advice)
                    footer(profile)
                }
                .padding(.horizontal, Theme.padding)
                .padding(.vertical, 12)
            }
            // Only while asleep: an empty bottomBar still draws its padded backing.
            .safeAreaInset(edge: .bottom) {
                if let active, active.start <= now {
                    asleepControls
                        .padding(.horizontal, Theme.padding)
                        .padding(.top, 10)
                        .padding(.bottom, 6)
                        .background(.bar)
                }
            }
        }
        .animation(.snappy, value: active)
        .animation(.snappy, value: storedNaps.count)
        .navigationTitle("Sleep")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadHealth() }
        .sheet(item: $sheet) { kind in
            switch kind {
            case .profile:
                JetLagProfileSheet(profile: storedProfile ?? JetLagProfile(), showsAdvice: false) { storedProfile = $0 }
            case .log:
                LogNapSheet { storedNaps = (storedNaps + [$0]).sorted { $0.start > $1.start } }
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: active == nil)
    }

    // MARK: Hero

    @ViewBuilder
    private func hero(now: Date, naps: [Nap], profile: JetLagProfile) -> some View {
        if let active {
            AsleepCard(nap: active, now: now)
            NapAlarmStatus()
        } else if let woke = naps.first(where: { $0.energy == nil && $0.end <= now && now.timeIntervalSince($0.end) < 2 * 3600 }) {
            WokeCard(nap: woke)
        } else {
            SleepRing(now: now, profile: profile)
        }
    }

    @ViewBuilder
    private var asleepControls: some View {
        if active != nil {
            HStack(spacing: Theme.spacing) {
                Button("Cancel") { NapSession.cancel() }
                    .buttonStyle(.soft)
                    .frame(maxWidth: 120)
                Button { NapSession.finish() } label: { Label("I'm up", systemImage: "sun.max.fill") }
                    .buttonStyle(.primary)
            }
        }
    }

    // MARK: Today

    private func today(now: Date, naps: [Nap], nights: [PastNight], profile: JetLagProfile, advice: NapAdvice) -> some View {
        let debt = SleepTrend.debt(nights, usualHours: profile.sleepHours)
        let energy = EnergyChart.mean(naps)
        let streak = SleepTrend.wakeStreak(nights, usualWake: profile.usualWake)
        return VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Today")
            HStack(alignment: .top, spacing: 10) {
                CoffeeTile(now: now, bed: advice.current(at: now).bed)
                StatTile(symbol: "bolt.fill", title: "Energy",
                         value: energy.map { $0.formatted(.number.precision(.fractionLength(1))) + " / 5" } ?? "–",
                         tint: energy.map { EnergyChart.tint(Int($0.rounded())) } ?? .secondary,
                         detail: energy == nil ? "Rate how you feel after waking" : "How you felt waking, recently",
                         info: Self.energyInfo)
                StatTile(symbol: "bed.double.fill", title: "Sleep debt",
                         value: nights.isEmpty ? "–" : debt < 15 * 60 ? "None" : ActivityLog.duration(debt),
                         tint: debt >= 3 * 3600 ? Theme.Tone.bad : debt >= 3600 ? Theme.Tone.warn : Theme.Tone.good,
                         detail: nights.isEmpty ? "Sleep or connect Health" : "Short of \(Int(profile.sleepHours)) h/night, last 7",
                         info: Self.debtInfo(streak: streak))
            }
        }
    }

    // MARK: Trends

    private func trends(nights: [PastNight], naps: [Nap], profile: JetLagProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Trend", selection: $trend) {
                ForEach(Trend.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            Group {
                switch trend {
                case .score: ScoreChart(nights: nights, usualHours: profile.sleepHours)
                case .energy: EnergyChart(naps: naps)
                }
            }
            .frame(height: 120)
        }
        .padding(14)
        .background(Theme.cardFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: Nights

    private func nightsSection(_ nights: [PastNight], profile: JetLagProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel(title: "Nights") { InfoButton(label: "About nights", text: Self.nightsInfo) }
                Spacer()
                Button { sheet = .log } label: { Image(systemName: "plus.circle.fill").font(.title3) }
                    .accessibilityLabel("Log past sleep")
            }
            if nights.isEmpty {
                Text("Nights you sleep from here show up with a score.").font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(showsAllNights ? nights : Array(nights.prefix(3))) { night in
                PastNightRow(night: night, usualHours: profile.sleepHours)
            }
            if nights.count > 3 {
                Button(showsAllNights ? "Show less" : "Show all \(nights.count)") { showsAllNights.toggle() }.font(.label)
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

    // MARK: Naps

    @ViewBuilder
    private func napsSection(_ naps: [Nap], now: Date, advice: NapAdvice) -> some View {
        let short = naps.filter { !$0.isNight }
        if !short.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel("Naps")
                if let nap = short.first(where: { $0.night == nil && !Calendar.current.isDate($0.start, inSameDayAs: now)
                    && now.timeIntervalSince($0.start) < 3 * 86_400 }) {
                    ratePrompt(nap)
                }
                ForEach(showsAllNaps ? short : Array(short.prefix(3))) { nap in
                    NapRow(nap: nap, level: advice.tonight(start: nap.start, minutes: nap.minutes, bed: nap.bed))
                        .contextMenu {
                            ForEach(Nap.Night.allCases) { night in
                                Button(night.title, systemImage: night.symbol) { rate(nap, night) }
                            }
                            Button("Delete", systemImage: "trash", role: .destructive) { storedNaps.removeAll { $0.id == nap.id } }
                        }
                }
                if short.count > 3 {
                    Button(showsAllNaps ? "Show less" : "Show all \(short.count)") { showsAllNaps.toggle() }.font(.label)
                }
            }
        }
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

    private func rate(_ nap: Nap, _ night: Nap.Night?) {
        var naps = storedNaps
        guard let i = naps.firstIndex(where: { $0.id == nap.id }) else { return }
        naps[i].night = night
        storedNaps = naps
    }

    // MARK: Footer

    private func footer(_ profile: JetLagProfile) -> some View {
        let calendar = Calendar.current
        let bed = SleepNow.clock(calendar.clockTime(minutes: profile.usualBedtime, of: .now))
        let wake = SleepNow.clock(calendar.clockTime(minutes: profile.usualWake, of: .now))
        return VStack(alignment: .leading, spacing: 10) {
            Button { sheet = .profile } label: {
                HStack {
                    Label("Usually \(bed) – \(wake)", systemImage: "person.crop.circle")
                    Spacer()
                    Text("Change").fontWeight(.semibold)
                }
                .font(.subheadline)
            }
            .buttonStyle(.borderless)
            Text(Self.howItWorks)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }

    private static var howItWorks: String { """
        A sleep cycle is about \(SleepCycle.current.minutes) minutes, plus ~\(SleepCycle.current.fallAsleepMinutes) to fall asleep; waking at a cycle's end feels easier. \
        Green: 5–6 cycles or a short nap. Orange: 3–4. Red: 1–2. Coffee cutoff is 8 h before your usual bed; \
        under 90 min since the last cup is too soon. A rough guide, not medical advice.
        """ }

    private static let energyInfo = """
        How rested you've been. After each sleep or nap, rate how you feel 1–5; this averages your recent ratings.
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
        Nights slept from here, plus the Health app's on days with nothing logged. Score 0–100: up to 60 for \
        length against your usual hours, 20 for waking between cycles, 20 for how you felt. Sleep debt: hours \
        short of your usual over the last 7 nights. Steady wake: nights in a row up within 30 min of your usual time.
        """
}

#Preview {
    NavigationStack { SleepTimeView() }
}
