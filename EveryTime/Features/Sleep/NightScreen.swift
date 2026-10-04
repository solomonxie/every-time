import SwiftUI

/// The page from the tap to sleep until "I'm up": waiting for a later bed, asleep, ringing, just up.
/// Black, dim, one answer, one button.
struct NightScreen: View {
    enum Phase: Equatable {
        case waiting(ActiveNap), asleep(ActiveNap), ringing(ActiveNap), woke(Nap)
    }

    let phase: Phase
    let now: Date
    let onCancel: (ActiveNap) -> Void
    let onDismissWoke: () -> Void

    private var isRinging: Bool { if case .ringing = phase { true } else { false } }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                switch phase {
                case .waiting(let nap): waiting(nap)
                case .asleep(let nap): asleep(nap)
                case .ringing(let nap): ringing(nap)
                case .woke(let nap): woke(nap)
                }
            }
            .padding(.horizontal, Theme.padding)
            .padding(.top, 24)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Color.black.ignoresSafeArea())
        .bottomBar { bar }
        .colorScheme(.dark)
        .tint(.orange)
        .modifier(NightDim())
        .sensoryFeedback(.warning, trigger: isRinging)
    }

    // MARK: Waiting for bed

    /// Counts down to bed, then becomes Asleep on its own.
    private func waiting(_ nap: ActiveNap) -> some View {
        let left = nap.start.timeIntervalSince(now)
        let windingDown = left <= WindDown.lead
        return Group {
            clock(now)
            VStack(spacing: 6) {
                Text("Bed \(SleepNow.clock(nap.start)) · in \(ActivityLog.duration(max(0, left)))")
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.85))
                Text(windingDown ? "Wind down · lights low, screens away" : "Alarm \(SleepNow.clock(nap.alarm)) is set")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(windingDown ? Color.indigo.opacity(0.9) : Self.dim)
            }
            SleepRing(now: now, plan: nap)
                .frame(maxWidth: 240)
                .opacity(0.7)
            Text("Asleep from \(SleepNow.clock(nap.start)) unless you tap below first; up at \(SleepNow.clock(nap.alarm)).")
                .font(.footnote).foregroundStyle(Self.dim)
                .multilineTextAlignment(.center)
            NapAlarmStatus().opacity(0.6)
        }
    }

    // MARK: Asleep

    private func asleep(_ nap: ActiveNap) -> some View {
        let check = WakeCheck(start: nap.start, now: now)
        return Group {
            clock(now)
            VStack(spacing: 6) {
                alarmLine(nap)
                Text(answer(check, nap: nap))
                    .font(.title3.weight(.medium))
                    .foregroundStyle(check.isFirstMinutes ? Self.dim : check.isAtCycleEnd ? Theme.Tone.good : Theme.Tone.warn)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            SleepRing(now: now, plan: nap)
                .frame(maxWidth: 240)
                .opacity(0.7)
            HStack(spacing: 10) {
                CycleDots(count: max(1, Int((nap.alarm.timeIntervalSince(nap.start) - WakeCheck.fallAsleep) / WakeCheck.cycle)),
                          tint: .indigo, done: Double(check.cycles) + check.intoCycle / WakeCheck.cycle)
                Text("\(check.cycles) of \(max(1, Int((nap.alarm.timeIntervalSince(nap.start) - WakeCheck.fallAsleep) / WakeCheck.cycle))) cycles")
                    .font(.footnote).foregroundStyle(Self.dim)
            }
            chipRow("Up at", times: upAt(nap, check: check), current: nap.ringsAlarm ? nap.alarm : nil) { NapSession.moveAlarm(to: $0) }
            NapAlarmStatus().opacity(0.6)
        }
    }

    private func answer(_ check: WakeCheck, nap: ActiveNap) -> String {
        if check.isFirstMinutes { return "Just dozed off" }
        if check.isAtCycleEnd { return "Between cycles · OK to get up" }
        return "Mid-cycle · sleep on, \(SleepNow.clock(check.nextCycleEnd)) feels better"
    }

    private func alarmLine(_ nap: ActiveNap) -> some View {
        Menu {
            if nap.ringsAlarm {
                Button("Turn off alarm", systemImage: "alarm.slash") { NapSession.turnOffAlarm() }
            } else {
                Button("Alarm at \(SleepNow.clock(nap.alarm))", systemImage: "alarm.fill") { NapSession.moveAlarm(to: nap.alarm) }
            }
        } label: {
            HStack(spacing: 6) {
                Text(nap.ringsAlarm ? "Alarm \(SleepNow.clock(nap.alarm)) · in \(ActivityLog.duration(max(0, nap.alarm.timeIntervalSince(now))))"
                     : "Alarm off · up when you wake")
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                if !NapSession.canCancel(nap, at: now) {
                    Image(systemName: "chevron.down").font(.caption.weight(.bold)).foregroundStyle(Self.dim)
                }
            }
            .foregroundStyle(.white.opacity(0.85))
        }
        .disabled(NapSession.canCancel(nap, at: now))
    }

    /// Cycle ends on the night's own grid, from now to one past the alarm, with the alarm itself.
    private func upAt(_ nap: ActiveNap, check: WakeCheck) -> [Date] {
        let soonest = now.addingTimeInterval(10 * 60)
        var times = (0..<12).map { check.nextCycleEnd.addingTimeInterval(Double($0) * WakeCheck.cycle) }
            .filter { $0 >= soonest && $0 <= nap.alarm.addingTimeInterval(WakeCheck.cycle + WakeCheck.slack) }
        if nap.ringsAlarm, nap.alarm >= soonest, !times.contains(where: { abs($0.timeIntervalSince(nap.alarm)) < 120 }) {
            times.append(nap.alarm)
        }
        return Array(times.sorted().prefix(5))
    }

    // MARK: Ringing

    private func ringing(_ nap: ActiveNap) -> some View {
        let late = now.timeIntervalSince(nap.alarm)
        let check = WakeCheck(start: nap.start, now: now)
        return Group {
            clock(now)
            VStack(spacing: 6) {
                Label(late < 90 * 60 ? "Get up" : "Alarm was at \(SleepNow.clock(nap.alarm)) · \(ActivityLog.duration(late)) ago", systemImage: "sun.max.fill")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.Tone.warn)
                    .multilineTextAlignment(.center)
                Text("\(ActivityLog.duration(check.elapsed)) · \(check.detail)")
                    .font(.subheadline).foregroundStyle(Self.dim)
                    .multilineTextAlignment(.center)
            }
            moreChips
        }
    }

    // MARK: Woke

    private func woke(_ nap: Nap) -> some View {
        let check = WakeCheck(start: nap.start, now: nap.end)
        let hour = Calendar.current.component(.hour, from: nap.end)
        return Group {
            clock(nap.end)
            VStack(spacing: 6) {
                Text(hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening")
                    .font(.system(.title, design: .rounded, weight: .bold))
                Text("\(ActivityLog.duration(nap.duration)) · \(check.headline.lowercased())")
                    .font(.subheadline).foregroundStyle(Self.dim)
            }
            VStack(spacing: 12) {
                Text("How do you feel?").font(.title3.weight(.medium))
                HStack(spacing: 10) {
                    ForEach(Nap.energyChoices, id: \.self) { level in
                        Button { NapSession.rate(nap.id, energy: level) } label: {
                            VStack(spacing: 6) {
                                Image(systemName: Self.symbol(level)).font(.title)
                                Text(Nap.energyTitle(level)).font(.subheadline.weight(.semibold))
                            }
                            .foregroundStyle(EnergyChart.tint(level))
                            .frame(maxWidth: .infinity, minHeight: 84)
                            .background(EnergyChart.tint(level).opacity(0.15), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Nap.energyTitle(level))
                    }
                }
            }
            VStack(spacing: 8) {
                Text("Back to sleep?").font(.footnote).foregroundStyle(Self.dim)
                moreChips
            }
            Button("Not now") { onDismissWoke() }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Self.dim)
                .padding(.top, 8)
        }
    }

    private static func symbol(_ level: Int) -> String {
        level <= 1 ? "battery.0percent" : level <= 3 ? "battery.50percent" : "battery.100percent"
    }

    // MARK: Shared

    private static let dim = Color.white.opacity(0.55)

    private func clock(_ time: Date) -> some View {
        Text(SleepNow.clock(time))
            .font(.clock(72, weight: .medium))
            .foregroundStyle(.white.opacity(0.85))
            .contentTransition(.numericText())
    }

    /// "+20 min" and "+1 cycle" from now: log this sleep and start the next.
    private var moreChips: some View {
        let cycle = Int((WakeCheck.fallAsleep + WakeCheck.cycle) / 60)
        return HStack(spacing: 10) {
            chip("+20 min · \(SleepNow.clock(now.addingTimeInterval(20 * 60)))", isCurrent: false) { NapSession.sleepMore(minutes: 20) }
            chip("+1 cycle · \(SleepNow.clock(now.addingTimeInterval(Double(cycle) * 60)))", isCurrent: false) { NapSession.sleepMore(minutes: cycle) }
        }
    }

    private func chipRow(_ title: String, times: [Date], current: Date?, action: @escaping (Date) -> Void) -> some View {
        VStack(spacing: 8) {
            Text(title.uppercased()).font(.label).tracking(0.8).foregroundStyle(Self.dim)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(times, id: \.self) { time in
                        let isCurrent = current.map { abs($0.timeIntervalSince(time)) < 120 } ?? false
                        chip(SleepNow.clock(time) + (isCurrent ? " ✓" : ""), isCurrent: isCurrent) { action(time) }
                    }
                }
            }
            .scrollClipDisabled()
        }
    }

    private func chip(_ text: String, isCurrent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .padding(.horizontal, 14)
                .frame(minHeight: 40)
                .foregroundStyle(isCurrent ? Color.white : .white.opacity(0.8))
                .background(isCurrent ? AnyShapeStyle(Color.indigo.opacity(0.7)) : AnyShapeStyle(Color.white.opacity(0.1)), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var bar: some View {
        switch phase {
        case .waiting(let nap):
            HStack(spacing: Theme.spacing) {
                Button("Cancel") { onCancel(nap) }
                    .buttonStyle(.soft)
                    .frame(maxWidth: 120)
                Button { NapSession.inBedNow() } label: { Label("Asleep already", systemImage: "moon.zzz.fill") }
                    .buttonStyle(.primary)
            }
        case .asleep(let nap):
            HStack(spacing: Theme.spacing) {
                if NapSession.canCancel(nap, at: now) {
                    Button("Cancel") { onCancel(nap) }
                        .buttonStyle(.soft)
                        .frame(maxWidth: 120)
                }
                upButton
            }
        case .ringing:
            upButton
        case .woke:
            EmptyView()
        }
    }

    private var upButton: some View {
        Button { NapSession.finish() } label: { Label("I'm up", systemImage: "sun.max.fill") }
            .buttonStyle(.primary)
    }
}

/// One dot per cycle, filled as far as the sleep has got.
struct CycleDots: View {
    let count: Int
    let tint: Color
    var done: Double? = nil

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(done.map { Double(i) < $0 } ?? true ? tint : tint.opacity(0.25))
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Lowers the screen while the night screen is up, and puts it back after.
private struct NightDim: ViewModifier {
    static let level: CGFloat = 0.2
    @Environment(\.scenePhase) private var scenePhase
    @State private var saved: CGFloat?

    func body(content: Content) -> some View {
        content
            .onAppear(perform: dim)
            .onDisappear(perform: restore)
            .onChange(of: scenePhase) { _, phase in phase == .active ? dim() : restore() }
    }

    private var screen: UIScreen? {
        (UIApplication.shared.connectedScenes.first { $0.activationState == .foregroundActive } as? UIWindowScene)?.screen
    }

    private func dim() {
        guard let screen, saved == nil, screen.brightness > Self.level else { return }
        saved = screen.brightness
        screen.brightness = Self.level
    }

    private func restore() {
        guard let saved, let screen else { return }
        screen.brightness = saved
        self.saved = nil
    }
}
