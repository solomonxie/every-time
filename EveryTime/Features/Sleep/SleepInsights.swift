import SwiftUI

/// Cycle length, sleep debt and energy at a glance, then the trend charts.
struct SleepInsights: View {
    let nights: [PastNight]
    let naps: [Nap]
    let profile: JetLagProfile
    let cycle: SleepCycle
    let onCycle: () -> Void

    var body: some View {
        let need = SleepTrend.need(profile)
        let debt = SleepTrend.debt(nights, naps: naps, need: need)
        let rated = EnergyChart.rated(naps)
        let energy = EnergyChart.mean(rated)
        let streak = SleepTrend.wakeStreak(nights, usualWake: profile.usualWake)
        let perNight = NapAdvice.hours(need / 3600)
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Insights")
            VStack(alignment: .leading, spacing: 14) {
                Button(action: onCycle) {
                    row("arrow.triangle.2.circlepath", "Cycle length", value: "\(cycle.minutes) min",
                        tint: .indigo, detail: cycle.sourceText.prefix(1).uppercased() + cycle.sourceText.dropFirst(), info: Self.cycleInfo)
                }
                .buttonStyle(.plain)
                if !nights.isEmpty {
                    row("bed.double.fill", "Sleep debt",
                        value: debt < 15 * 60 ? "None" : ActivityLog.duration(debt),
                        tint: debt >= 3 * 3600 ? Theme.Tone.bad : debt >= 3600 ? Theme.Tone.warn : Theme.Tone.good,
                        detail: debt < 15 * 60 ? "On track for \(perNight)/night over the last 7 days"
                            : "Short of \(perNight)/night over the last 7 days, naps count",
                        info: Self.debtInfo(streak: streak))
                }
                if let energy {
                    row("bolt.fill", "Energy",
                        value: energy.formatted(.number.precision(.fractionLength(1))) + " / 5",
                        tint: EnergyChart.tint(Int(energy.rounded())),
                        detail: "How rested you felt waking, last 2 weeks", info: Self.energyInfo)
                }
                if nights.count >= 2 {
                    Text("Sleep score").font(.label).foregroundStyle(.secondary)
                    ScoreChart(nights: nights, need: need).frame(height: 100)
                }
                if rated.count >= 2 {
                    Text("Energy on waking").font(.label).foregroundStyle(.secondary)
                    EnergyChart(rated: rated).frame(height: 100)
                }
            }
            .padding(14)
            .background(Theme.cardFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func row(_ symbol: String, _ title: String, value: String, tint: Color, detail: String, info: String) -> some View {
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

    private static var cycleInfo: String { """
        How long one sleep cycle runs for you. Each time you wake before the alarm the app notes how long \
        you slept; after \(SleepCycle.minWakes) such wakes it picks the length (70–120 min) that lands them on cycle ends, \
        and the ring, chips and "wakes between cycles" use it. Tap to set it yourself instead.
        """ }

    private static let energyInfo = """
        How rested you've been. After each sleep or nap, rate how you feel; this averages your ratings from the last 2 weeks.
        Low? Try waking at a cycle's end or a shorter nap. The Energy trend shows which sleeps worked.
        """

    private static func debtInfo(streak: Int) -> String {
        """
        Sleep you missed over the last 7 days, by the day you woke, against your usual hours (at least the recommended 7 h asleep). \
        Naps in that time pay it back by the time actually asleep. Under 1 h is fine; 3 h+ is worth catching up.
        Pay it back with an earlier bedtime or an early-afternoon nap, not a long lie-in — waking at a steady time helps most \
        (\(streak) \(streak == 1 ? "day" : "days") in a row so far).
        """
    }
}
