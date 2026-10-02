import SwiftUI
import UserNotifications

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
                    .font(.clock(22))
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
        .background(Theme.cardFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
        Group {
            if now < nap.start { beforeBed } else { asleep }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .sensoryFeedback(.warning, trigger: now >= nap.alarm)
    }

    private var beforeBed: some View {
        SleepRing(now: now, plan: nap)
    }

    private var asleep: some View {
        let check = WakeCheck(start: nap.start, now: now)
        let isUp = now >= nap.alarm
        let ends = (1...3).map { check.nextCycleEnd.addingTimeInterval(Double($0 - 1) * WakeCheck.cycle) }
        return VStack(alignment: .leading, spacing: 16) {
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
            alarmLine(isUp: isUp)
            if !isUp, !check.isFirstMinutes { rightNow(check) }
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
    }

    private func alarmLine(isUp: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "alarm.fill").foregroundStyle(Color.indigo)
            Text(SleepNow.clock(nap.alarm)).font(.clock(22, weight: .semibold))
            if !isUp {
                Text("in \(ActivityLog.duration(nap.alarm.timeIntervalSince(now)))").font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    /// Woke before the alarm: get up now, or how much more sleep still ends on a cycle.
    private func rightNow(_ check: WakeCheck) -> some View {
        let back = SleepPlan.backToSleep(now: now, alarm: nap.alarm)
        let upNow = check.isAtCycleEnd ? "Between cycles — getting up now should feel OK."
            : "Mid-cycle — getting up now will likely feel groggy."
        let more = back.map { "Back to sleep: \($0.cycles) more \($0.cycles == 1 ? "cycle" : "cycles") fit — up at \(SleepNow.clock($0.time))." }
            ?? "Under a full cycle left before the alarm — better to get up now, or rest until it rings."
        return VStack(alignment: .leading, spacing: 8) {
            Text("Awake now?").font(.label).foregroundStyle(.secondary)
            Text(upNow + " " + more).font(.subheadline).fixedSize(horizontal: false, vertical: true)
            if let back, abs(back.time.timeIntervalSince(nap.alarm)) >= 120 {
                Button("Set alarm to \(SleepNow.clock(back.time))") { NapSession.moveAlarm(to: back.time) }
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                        Button { NapSession.start(minutes: max(1, Int((row.time.timeIntervalSince(.now) / 60).rounded()))) } label: {
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
        content.body = "Lights low, screens off — in bed by \(SleepNow.clock(bed))."
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
