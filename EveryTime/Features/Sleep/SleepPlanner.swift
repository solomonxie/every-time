import SwiftUI
import UserNotifications

/// The top of the Sleep page: pick which end of the night you're deciding, see the other end as a ladder of cycles.
struct SleepPlanner: View {
    let now: Date
    let profile: JetLagProfile
    let advice: NapAdvice
    @Stored("sleep.plan.mode") private var mode = SleepPlan.Mode.sleep
    @Stored("sleep.plan.wake") private var wakeMinutes: Int? = nil
    /// Nil = now.
    @State private var bedAt: Date?
    @State private var editsTime = false
    @State private var reminder: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                ModeTile(symbol: "sun.horizon.fill", title: "Wake up by", value: SleepNow.clock(wake),
                         isOn: mode == .wake) { pick(.wake) }
                ModeTile(symbol: "moon.fill", title: "Sleep at", value: bedAt.map(SleepNow.clock) ?? "Now",
                         isOn: mode == .sleep) { pick(.sleep) }
            }
            if editsTime { picker }
            switch mode {
            case .wake: wakeFirst
            case .sleep: sleepFirst
            }
        }
        .sensoryFeedback(.selection, trigger: mode)
        .sensoryFeedback(.success, trigger: reminder)
        .task { reminder = await WindDown.pending() }
    }

    /// Tapping the chosen tile again opens its time.
    private func pick(_ new: SleepPlan.Mode) {
        withAnimation(.snappy) {
            if mode == new { editsTime.toggle() } else { mode = new; editsTime = false }
        }
    }

    @ViewBuilder
    private var picker: some View {
        VStack(spacing: 8) {
            switch mode {
            case .wake:
                DatePicker("Wake up by", selection: Binding { wake } set: { wakeMinutes = Self.minutes(of: $0) },
                           displayedComponents: .hourAndMinute)
            case .sleep:
                DatePicker("Sleep at", selection: Binding { bedAt ?? now } set: { bedAt = $0 },
                           displayedComponents: .hourAndMinute)
                if bedAt != nil {
                    Button("Back to now") { withAnimation(.snappy) { bedAt = nil; editsTime = false } }
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
        .datePickerStyle(.wheel)
        .labelsHidden()
        .frame(maxWidth: .infinity)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: Wake first

    private var wake: Date {
        SleepSuggestion.nextOccurrence(ofMinutes: wakeMinutes ?? profile.usualWake, after: now)
    }

    private var wakeFirst: some View {
        let wake = wake
        let answer = SleepPlan.answer(now: now, wake: wake)
        return VStack(alignment: .leading, spacing: 14) {
            Verdict(title: answer.wait.map { "Wait until \(SleepNow.clock($0.time))" }
                        ?? (answer.nowWake == nil ? "Under a cycle left" : "Sleep now"),
                    detail: verdictDetail(answer, wake: wake))
            VStack(spacing: 6) {
                ForEach(SleepPlan.bedtimes(for: wake).sorted { $0.time < $1.time }) { row in
                    let isPast = row.time < now.addingTimeInterval(-SleepPlan.nowSlack)
                    LadderRow(row: row, caption: "Fall asleep", status: isPast ? nil : SleepPlan.relative(row.time, now: now),
                              note: nil, isPick: row == answer.wait, isDim: isPast) {
                        if !isPast, row.time.addingTimeInterval(-WindDown.lead) > now { bell(for: row.time) }
                    }
                }
            }
            if let nowWake = answer.nowWake {
                Button { NapSession.start(minutes: Self.minutes(until: nowWake)) } label: {
                    Label("Sleep now · alarm \(SleepNow.clock(nowWake))", systemImage: "moon.zzz.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary)
                .opacity(answer.sleepsNow ? 1 : 0.85)
            } else {
                napButton
            }
        }
    }

    private func verdictDetail(_ answer: SleepPlan.Answer, wake: Date) -> String {
        if let wait = answer.wait {
            let instead = answer.nowWake.map { " Sleeping now, they'd end at \(SleepNow.clock($0)) instead." } ?? ""
            return "\(wait.cycles) cycles end right at \(SleepNow.clock(wake)).\(instead)"
        }
        guard let nowWake = answer.nowWake else { return "A \(NapAdvice.suggestedMinutes)-min nap beats waking mid-cycle." }
        return "\(answer.nowCycles) \(answer.nowCycles == 1 ? "cycle" : "cycles"), up at \(SleepNow.clock(nowWake))."
    }

    private func bell(for bed: Date) -> some View {
        let isSet = reminder == bed
        return Button {
            reminder = isSet ? nil : bed
            Task { isSet ? WindDown.cancel() : await WindDown.schedule(bed: bed) }
        } label: {
            Image(systemName: isSet ? "bell.fill" : "bell")
                .font(.subheadline)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(isSet ? "Cancel wind-down reminder" : "Remind me to wind down 30 minutes before")
    }

    // MARK: Sleep first

    private var sleepFirst: some View {
        let bed = bedAt ?? now
        let isNow = bedAt == nil
        let usualWake = SleepSuggestion.nextOccurrence(ofMinutes: profile.usualWake, after: bed)
        let rows = SleepPlan.wakeTimes(from: bed, includesNap: isNow).sorted { $0.time < $1.time }
        let pick = Self.pick(rows, usualWake: usualWake)
        return VStack(alignment: .leading, spacing: 14) {
            if let pick {
                Verdict(title: pick.cycles == 0 ? "Take a \(NapAdvice.suggestedMinutes)-min nap" : "Up at \(SleepNow.clock(pick.time))",
                        detail: pick.cycles == 0 ? "Too far from bedtime for whole cycles — a short nap won't touch tonight."
                            : "\(pick.cycles) cycles, the most that end by your usual \(SleepNow.clock(usualWake)).")
            }
            VStack(spacing: 6) {
                ForEach(rows) { row in
                    let ladder = LadderRow(row: row, caption: "Wake up", status: isNow ? "alarm" : nil,
                                           note: note(row, bed: bed, usualWake: usualWake), isPick: row == pick, isDim: false) {}
                    if isNow {
                        Button { NapSession.start(minutes: Self.minutes(until: row.time)) } label: { ladder }
                            .buttonStyle(.plain)
                    } else {
                        ladder
                    }
                }
            }
            if isNow {
                Text("Tap a time to sleep now with that alarm.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// What each choice costs: tonight's sleep for a daytime nap, sleeping in or a short night otherwise.
    private func note(_ row: SleepPlan.Row, bed: Date, usualWake: Date) -> String? {
        if row.cycles == 0 {
            return NapAdvice.tonightText(advice.tonight(start: bed, minutes: NapAdvice.suggestedMinutes))
        }
        if row.time > usualWake.addingTimeInterval(15 * 60) { return "Sleeping in past \(SleepNow.clock(usualWake))" }
        if row.cycles <= 2 { return advice.tonight(start: bed, minutes: Int(row.length / 60)) == .low ? "Long nap" : "Eats into tonight" }
        return nil
    }

    /// The longest night that still ends by the usual wake; by day, the nap.
    static func pick(_ rows: [SleepPlan.Row], usualWake: Date) -> SleepPlan.Row? {
        let fits = rows.filter { $0.cycles >= 3 && $0.time <= usualWake.addingTimeInterval(15 * 60) }
        return fits.last ?? rows.first { $0.cycles == 0 } ?? rows.first { $0.cycles == 5 }
    }

    private static func minutes(of date: Date) -> Int {
        Calendar.current.component(.hour, from: date) * 60 + Calendar.current.component(.minute, from: date)
    }

    static func minutes(until time: Date) -> Int {
        max(1, Int((time.timeIntervalSince(.now) / 60).rounded()))
    }

    private var napButton: some View {
        Button { NapSession.start(minutes: NapAdvice.suggestedMinutes) } label: {
            Label("Nap \(NapAdvice.suggestedMinutes) min", systemImage: "moon.zzz.fill").frame(maxWidth: .infinity)
        }
        .buttonStyle(.primary)
    }
}

/// One half of the "deciding" switch, showing its current time.
private struct ModeTile: View {
    let symbol: String
    let title: String
    let value: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Label(title, systemImage: symbol)
                    .font(.system(.footnote, design: .rounded, weight: .semibold))
                    .foregroundStyle(isOn ? Color.white.opacity(0.85) : .secondary)
                HStack(spacing: 4) {
                    Text(value)
                        .font(.clock(26, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if isOn {
                        Image(systemName: "chevron.down").font(.caption.weight(.bold)).opacity(0.7)
                    }
                }
                .foregroundStyle(isOn ? Color.white : .primary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isOn ? AnyShapeStyle(Color.indigo.gradient) : AnyShapeStyle(Theme.cardFill),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityHint(isOn ? "Change the time" : "")
    }
}

private struct Verdict: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(.title2, design: .rounded, weight: .bold))
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// "11:15 PM  ●●●●●  7h 45m       in 25m": one rung of the ladder.
struct LadderRow<Accessory: View>: View {
    let row: SleepPlan.Row
    let caption: String
    let status: String?
    let note: String?
    let isPick: Bool
    let isDim: Bool
    @ViewBuilder let accessory: Accessory

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2).fill(row.level.tint).frame(width: 4, height: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(SleepNow.clock(row.time))
                    .font(.clock(22, weight: isPick ? .bold : .regular))
                HStack(spacing: 6) {
                    CycleDots(count: row.cycles, tint: row.level.tint)
                    Text(row.cycles == 0 ? "\(NapAdvice.suggestedMinutes) min" : NapAdvice.hours(row.length / 3600))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                if let note {
                    Text(note).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 4)
            if isPick {
                Text("Best")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .foregroundStyle(.white)
                    .background(Color.indigo, in: Capsule())
            }
            if status == "alarm" {
                Image(systemName: "alarm").foregroundStyle(Color.indigo)
            } else if let status {
                Text(status).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            accessory
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isPick ? Color.indigo.opacity(0.12) : Theme.cardFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(isPick ? Color.indigo.opacity(0.5) : .clear))
        .opacity(isDim ? 0.4 : 1)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(caption) \(SleepNow.clock(row.time)), \(row.title)\(isPick ? ", best" : "")")
    }
}

/// One dot per 90-minute cycle; a ring for a short nap.
struct CycleDots: View {
    let count: Int
    let tint: Color
    var done: Double? = nil

    var body: some View {
        HStack(spacing: 3) {
            if count == 0 {
                Circle().strokeBorder(tint, lineWidth: 1.5).frame(width: 7, height: 7)
            }
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(done.map { Double(i) < $0 } ?? true ? tint : tint.opacity(0.25))
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Asleep

/// While asleep: when the alarm rings, cycles so far, and the next good times to get up. Tap one to move the alarm.
struct AsleepCard: View {
    let nap: ActiveNap
    let now: Date

    var body: some View {
        let check = WakeCheck(start: nap.start, now: now)
        let isUp = now >= nap.alarm
        let ends = (1...3).map { check.nextCycleEnd.addingTimeInterval(Double($0 - 1) * WakeCheck.cycle) }
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isUp ? "Time to get up" : check.isAtCycleEnd ? "Good moment to get up" : "Asleep")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(isUp ? Theme.Tone.warn : .primary)
                Text("Since \(SleepNow.clock(nap.start)) · \(ActivityLog.duration(check.elapsed))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                CycleDots(count: max(1, Int((nap.alarm.timeIntervalSince(nap.start) - WakeCheck.fallAsleep) / WakeCheck.cycle)),
                          tint: .indigo, done: Double(check.cycles) + check.intoCycle / WakeCheck.cycle)
                Text(check.detail).font(.footnote).foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                Image(systemName: "alarm.fill").foregroundStyle(Color.indigo)
                Text(SleepNow.clock(nap.alarm)).font(.clock(22, weight: .semibold))
                if !isUp {
                    Text("in \(ActivityLog.duration(nap.alarm.timeIntervalSince(now)))").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            if !isUp {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Move the alarm to a cycle's end").font(.label).foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        ForEach(ends, id: \.self) { end in
                            let isAlarm = abs(end.timeIntervalSince(nap.alarm)) < 120
                            Button { NapSession.moveAlarm(to: end) } label: {
                                Text(SleepNow.clock(end))
                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                    .monospacedDigit()
                                    .frame(maxWidth: .infinity, minHeight: 40)
                                    .foregroundStyle(isAlarm ? Color.white : .primary)
                                    .background(isAlarm ? AnyShapeStyle(Color.indigo) : AnyShapeStyle(Theme.cardFill), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .sensoryFeedback(.warning, trigger: isUp)
    }
}

// MARK: - Just woke

/// Right after "I'm up": how you feel, and a way back to sleep that still ends on a cycle.
struct WokeCard: View {
    let nap: Nap
    @State private var sleepsMore = false

    var body: some View {
        let check = WakeCheck(start: nap.start, now: nap.end)
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("How do you feel?").font(.system(.title2, design: .rounded, weight: .bold))
                Text("Up at \(SleepNow.clock(nap.end)) after \(ActivityLog.duration(nap.duration)) · \(check.headline.lowercased())")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                ForEach(Nap.energyRange, id: \.self) { level in
                    Button { NapSession.rate(nap.id, energy: level) } label: {
                        VStack(spacing: 4) {
                            Image(systemName: Self.symbol(level)).font(.title2)
                            Text(Nap.energyTitle(level)).font(.caption2.weight(.medium))
                        }
                        .foregroundStyle(EnergyChart.tint(level))
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .background(EnergyChart.tint(level).opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Nap.energyTitle(level))
                }
            }
            if sleepsMore {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sleep more, up at…").font(.label).foregroundStyle(.secondary)
                    ForEach(SleepPlan.wakeTimes(from: .now, includesNap: true).prefix(4)) { row in
                        Button { NapSession.start(minutes: SleepPlanner.minutes(until: row.time)) } label: {
                            LadderRow(row: row, caption: "Wake up", status: "alarm", note: nil, isPick: false, isDim: false) {}
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                Button { withAnimation(.snappy) { sleepsMore = true } } label: {
                    Label(check.isAtCycleEnd ? "Sleep more anyway" : "Not ready — sleep to the next cycle", systemImage: "moon.zzz.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.soft)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private static func symbol(_ level: Int) -> String {
        ["battery.0percent", "battery.25percent", "battery.50percent", "battery.75percent", "battery.100percent"][min(4, max(0, level - 1))]
    }
}

// MARK: - Wind down

/// One notification before a chosen bedtime, to start winding down.
enum WindDown {
    static let lead: TimeInterval = 30 * 60
    private static let id = "sleep.winddown"

    static func schedule(bed: Date) async {
        let center = UNUserNotificationCenter.current()
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
        let content = UNMutableNotificationContent()
        content.title = "Time to wind down"
        content.body = "Lights low, screens off — asleep by \(SleepNow.clock(bed))."
        content.userInfo = ["bed": bed.timeIntervalSince1970]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, bed.addingTimeInterval(-lead).timeIntervalSinceNow), repeats: false)
        try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    /// The bedtime of the reminder still pending, if any.
    static func pending() async -> Date? {
        await UNUserNotificationCenter.current().pendingNotificationRequests()
            .first { $0.identifier == id }
            .flatMap { $0.content.userInfo["bed"] as? Double }
            .map { Date(timeIntervalSince1970: $0) }
    }
}
