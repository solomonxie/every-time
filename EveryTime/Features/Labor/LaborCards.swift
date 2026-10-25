import Charts
import SwiftUI

/// A red note on top with a Call button; nothing dials unless tapped.
struct FlagBanner: View {
    let flag: LaborAnalysis.Flag
    let phone: String
    let call: () -> Void
    let setNumber: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.Tone.bad)
            VStack(alignment: .leading, spacing: 8) {
                Text(flag.text).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                if phone.isEmpty {
                    Button(flag.isEmergency ? "Add the emergency number" : "Add the hospital's number", action: setNumber).font(.subheadline)
                } else {
                    Button(action: call) {
                        Label(flag.isEmergency ? "Call \(phone) now" : "Call now", systemImage: "phone.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.Tone.bad)
                }
            }
            Spacer(minLength: 0)
        }
        .tintedCard(Theme.Tone.bad, padding: 14)
    }
}

/// What to do now, in plain words.
struct AdviceView: View {
    let advice: LaborAnalysis.Advice
    let phone: String
    let call: () -> Void
    let setNumber: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(advice.headline)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(tint)
                .fixedSize(horizontal: false, vertical: true)
            Text(advice.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if advice.tone == .go {
                if phone.isEmpty {
                    Button("Add the hospital's number", action: setNumber).font(.subheadline).padding(.top, 4)
                } else {
                    Button("Call the hospital", action: call)
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.Tone.good)
                        .padding(.top, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var tint: Color {
        switch advice.tone {
        case .calm: .primary
        case .ready: .accentColor
        case .go: Theme.Tone.good
        case .urgent: Theme.Tone.bad
        }
    }
}

/// The go rule as three numbers, each against its goal; green once all three are met.
struct GoalRow: View {
    let check: LaborAnalysis.RuleCheck
    let firstSign: Bool

    var body: some View {
        let rule = check.rule
        VStack(alignment: .leading, spacing: Theme.spacing) {
            Text(header(rule))
                .font(.footnote.weight(check.isMet ? .semibold : .regular))
                .foregroundStyle(check.isMet ? Theme.Tone.good : .secondary)
            HStack(alignment: .top, spacing: 8) {
                ForEach(check.conditions, id: \.title) { condition in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(condition.title).font(.footnote).foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            Text(condition.value).font(.clock(24, weight: .medium))
                            Image(systemName: condition.isMet ? "checkmark.circle.fill" : "xmark.circle")
                                .foregroundStyle(condition.isMet ? Theme.Tone.good : .secondary)
                        }
                        Text("goal \(condition.goal)").font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                    .accessibilityValue(condition.isMet ? "met" : "not met")
                }
            }
            if let hint = check.conditions.lazy.compactMap(\.hint).first {
                Text(hint).font(.caption).foregroundStyle(.secondary)
            }
            Text("Last \(LaborAnalysis.span(rule.window)), typical values.").font(.caption).foregroundStyle(.tertiary)
        }
        .tintedCard(check.isMet ? Theme.Tone.good : nil)
        .sensoryFeedback(.success, trigger: check.isMet) { !$0 && $1 }
    }

    private func header(_ rule: LaborRule) -> String {
        if check.isMet { return "Hospital rule \(rule.name) met — call now" }
        if firstSign { return "Your plan: call at the first sign. Hospital rule \(rule.name), for reference:" }
        return "Hospital rule \(rule.name): call when all three are ✓"
    }
}

/// Why the app says what it says: reasons, last hour vs the hour before, a chart, and how it works.
struct LaborDetails: View {
    let analysis: LaborAnalysis
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                let read = analysis.pattern
                Section {
                    LabeledContent("Looks like", value: read.pattern.title)
                    ForEach(read.reasons, id: \.text) { reason in
                        Label(reason.text, systemImage: reason.sign == .labor ? "arrow.up.right" : reason.sign == .practice ? "pause" : "minus")
                            .foregroundStyle(reason.sign == .labor ? Theme.Tone.warn : .primary)
                    }
                } header: {
                    Text("Why")
                } footer: {
                    Text("↗ points to labor, ⏸ points to practice contractions. Read from timing only — only a cervical check tells the stage.")
                }
                Section("Last hour vs the hour before") {
                    HourStats(analysis: analysis)
                }
                Section("Over time") {
                    LaborChart(analysis: analysis).frame(height: 180).padding(.vertical, 8)
                }
                Section("How it works") {
                    Text(Self.info).font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    static let info = """
    Apart = from the start of one contraction to the start of the next. Each lasts = start to end. \
    Typical = the middle value of the last hour, so one missed tap doesn't throw it off. \
    Taps under 10 s and contractions over 3 min (forgot to tap) aren't counted.

    Practice contractions (Braxton Hicks): irregular, not getting closer, mostly mild, ease with rest. \
    Labor: regular, closer, longer, stronger, and keep going whatever she does. \
    "Regular" here means the gaps vary 30% or less — the app's own cut-off; no medical one exists.

    \(LaborGuide.warningSigns) \
    Your care team's advice comes first. Not a medical device. Sources: Cleveland Clinic, NHS, ACOG, WHO, CDC.
    """
}

struct HourStats: View {
    let analysis: LaborAnalysis

    var body: some View {
        let hour = analysis.lastHour
        let before = analysis.hourBefore
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
            GridRow {
                Text("")
                Text("Last hour").font(.footnote).foregroundStyle(.secondary)
                Text("Hour before").font(.footnote).foregroundStyle(.secondary)
            }
            row("Contractions", "\(hour.count)", "\(before.count)")
            row("Apart", hour.medianInterval.map(LaborAnalysis.clock), before.medianInterval.map(LaborAnalysis.clock))
            row("Each lasts", hour.medianLength.map(LaborAnalysis.clock), before.medianLength.map(LaborAnalysis.clock))
        }
    }

    private func row(_ title: String, _ now: String?, _ before: String?) -> some View {
        GridRow {
            Text(title).font(.subheadline)
            Text(now ?? "—").font(.clock(20, weight: .regular))
            Text(before ?? "—").font(.clock(17, weight: .regular)).foregroundStyle(.secondary)
        }
    }
}

/// Bars = how long each lasted; line = minutes apart.
struct LaborChart: View {
    let analysis: LaborAnalysis

    var body: some View {
        let intervals = analysis.intervals
        let points = analysis.episode.filter { LaborAnalysis.countsLength($0) }
        Chart {
            ForEach(points) { c in
                BarMark(x: .value("Time", c.start), y: .value("Minutes", (c.length ?? 0) / 60), width: 4)
                    .foregroundStyle(by: .value("Series", "Lasted"))
            }
            ForEach(analysis.episode.filter { intervals[$0.id] != nil }) { c in
                LineMark(x: .value("Time", c.start), y: .value("Minutes", (intervals[c.id] ?? 0) / 60))
                    .foregroundStyle(by: .value("Series", "Apart"))
                    .interpolationMethod(.monotone)
                PointMark(x: .value("Time", c.start), y: .value("Minutes", (intervals[c.id] ?? 0) / 60))
                    .foregroundStyle(by: .value("Series", "Apart"))
                    .symbolSize(16)
            }
        }
        .chartForegroundStyleScale(["Lasted": Color.accentColor.opacity(0.6), "Apart": Theme.Tone.warn])
        .chartYAxisLabel("minutes")
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in AxisGridLine(); AxisValueLabel(format: .dateTime.hour().minute()) } }
        .accessibilityLabel("How long each contraction lasted and minutes apart, over time")
    }
}

/// Numbered steps for someone who has never timed a contraction.
struct LaborGuide: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Timing contractions — how it works").font(.headline)
            step(1, "When she feels a contraction start, tap the big blue button below.")
            step(2, "When it ends, tap the same button again. It's red while timing.")
            step(3, "Repeat for every contraction, all through labor. Everything is saved.")
            step(4, "After a few, this spot tells you in plain words: keep timing, or call the hospital.")
            step(5, "Waters broke, bleeding or baby moving less? Tap \"Waters, bleeding, other…\".")
            Text("Before labor: in ⚙ add the hospital's phone number and the due date.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Label(Self.warningSigns, systemImage: "exclamationmark.triangle")
                .font(.footnote)
                .foregroundStyle(Theme.Tone.bad)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tintedCard(nil)
    }

    /// CDC Hear Her urgent maternal warning signs, plus labor's own.
    static let warningSigns = "Call your care team any time for: waters breaking, bleeding, baby moving less, constant pain, fever, "
        + "bad headache or vision changes, swollen face or hands, chest pain, trouble breathing, or an urge to push."

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(n)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.accentColor, in: Circle())
            Text(text).font(.subheadline).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// First open: build the plan before labor. After Skip it shrinks to one "Finish setup" row.
struct SetupPrompt: View {
    let skipped: Bool
    let start: () -> Void
    let skip: () -> Void

    var body: some View {
        if skipped {
            Button(action: start) {
                Label("Finish setting up your labor plan", systemImage: "list.bullet.clipboard").font(.subheadline)
            }
            .buttonStyle(.soft)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("Set up your labor plan").font(.headline)
                Text("7 quick questions — first baby, hospital, how far, health. The app then knows when you should call and leave.")
                    .font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Start setup", action: start).buttonStyle(.borderedProminent)
                    Spacer()
                    Button("Later", action: skip).buttonStyle(.soft)
                }
            }
            .tintedCard(.accentColor)
        }
    }
}

extension View {
    /// Rounded card: tinted at 12% when `tint` is set, else the plain card fill.
    func tintedCard(_ tint: Color?, padding: CGFloat = 16) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.map { AnyShapeStyle($0.opacity(0.12)) } ?? AnyShapeStyle(Theme.cardFill),
                        in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
    }
}

/// Capsule choice chip, filled when on; at least 44 pt tall.
struct LaborChip: ButtonStyle {
    let isOn: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(isOn ? .semibold : .regular))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(isOn ? Color.white : .primary)
            .background(isOn ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Theme.cardFill), in: Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
            .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
