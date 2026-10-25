import SwiftUI

/// Before → Early → Active → Hospital → Born; tap a stage to read about it (outlined), nothing is saved.
struct StageBar: View {
    let stage: LaborStage
    var previewing: LaborStage?
    let pick: (LaborStage) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(LaborStage.allCases, id: \.self) { s in
                Button { pick(s) } label: {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(s <= stage ? Color.accentColor : Theme.cardFill)
                                .frame(width: s == stage ? 30 : 22, height: s == stage ? 30 : 22)
                            if s < stage {
                                Image(systemName: "checkmark").font(.caption2.weight(.bold)).foregroundStyle(.white)
                            }
                        }
                        .overlay {
                            if s == previewing {
                                Circle().strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [3, 3])).frame(width: 34, height: 34)
                            }
                        }
                        .frame(height: 30)
                        Text(s.short)
                            .font(.caption.weight(s == stage ? .bold : .regular))
                            .foregroundStyle(s == stage ? .primary : .secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(s.title)
                .accessibilityAddTraits(s == stage ? .isSelected : [])
            }
        }
        .background(alignment: .top) {
            Rectangle().fill(Theme.hairline).frame(height: 2).padding(.horizontal, 30).padding(.top, 14)
        }
    }
}

/// What's happening, what to do now, and when to move on, for the current stage.
struct StageCard: View {
    let stage: LaborStage
    let rule: LaborRule
    var isPreview = false

    var body: some View {
        let copy = Self.copy(stage, rule: rule)
        Card {
            VStack(alignment: .leading, spacing: 4) {
                Text(isPreview ? stage.title : "You're here: \(stage.title)").font(.system(.title3, design: .rounded, weight: .bold))
                Text(copy.happening).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            block("Do now", copy.doNow)
            if let next = stage.next { block("Move to \(next.short) when", copy.moveOn) }
        }
    }

    private func block(_ title: String, _ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased()).font(.label).tracking(0.8).foregroundStyle(.secondary)
            ForEach(lines, id: \.self) { line in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("•")
                    Text(line).fixedSize(horizontal: false, vertical: true)
                }
                .font(.subheadline)
            }
        }
    }

    static func copy(_ stage: LaborStage, rule: LaborRule) -> (happening: String, doNow: [String], moveOn: [String]) {
        let goal = "\(LaborAnalysis.clock(rule.interval)) apart, \(LaborAnalysis.clock(rule.length)) long, for \(LaborAnalysis.span(rule.window))"
        switch stage {
        case .before:
            return ("Practice contractions (Braxton Hicks) are normal now: irregular, and they don't get closer.",
                    ["Rest, drink water, change position.", "If contractions keep coming, time them with the blue button."],
                    ["They become regular — the app will ask you."])
        case .early:
            return ("Contractions get regular, often 5–20 min apart. This can take many hours, longest with a first baby.",
                    ["Stay home: rest, eat light, drink, shower.", "Time every contraction: tap when it starts, tap when it ends."],
                    ["They're \(goal) — the app will ask you.", "Or your care team tells you to come in."])
        case .active:
            return ("Contractions are close, long and strong — hard to talk through.",
                    ["Call the hospital and go. Bring the bag. She shouldn't drive.", "Keep timing on the way.",
                     "Urge to push or cord visible: stay put, get low, and call the emergency number for help."],
                    ["You arrive — tap Hospital above, then \"We're here now\"."])
        case .hospital:
            return ("The midwife takes over from here.",
                    ["Show them the summary (share button at the top).", "Timing is optional now.",
                     "Sent home in early labor? That's common and normal — tap Early and keep timing."],
                    ["Baby is born — tap Born above, then \"We're here now\"."])
        case .born:
            return ("Congratulations!", ["Rest. Everything from this labor stays in the timeline."], [])
        }
    }
}

/// Reading about another stage: say nothing is saved, and offer to really move there.
struct StagePreview: View {
    let stage: LaborStage
    let current: LaborStage
    let back: () -> Void
    let confirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Just looking at \(stage.title) — nothing is saved.").font(.subheadline)
            HStack {
                Button("Back to \(current.short)", action: back).buttonStyle(.soft)
                Spacer()
                Button(stage == .born ? "Baby is born…" : "We're here now", action: confirm).buttonStyle(.borderedProminent)
            }
        }
        .tintedCard(.accentColor)
    }
}

/// "Rule met — move to Active?" with Not yet / Yes.
struct StageSuggestion: View {
    let stage: LaborStage
    let reason: String
    let accept: () -> Void
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(reason).font(.subheadline)
            Text("Move to \(stage.title)?").font(.headline)
            HStack {
                Button("Not yet", action: dismiss).buttonStyle(.soft)
                Spacer()
                Button(stage == .active ? "Yes, we're going" : "Yes", action: accept)
                    .buttonStyle(.borderedProminent)
            }
        }
        .tintedCard(.accentColor)
    }
}

struct BirthCard: View {
    let birth: LaborAnalysis.Birth
    let startOver: () -> Void

    var body: some View {
        Card {
            Text("Born at \(birth.time.formatted(date: .abbreviated, time: .shortened))")
                .font(.system(.title2, design: .rounded, weight: .bold))
            if let start = birth.laborStart {
                Text("\(LaborAnalysis.span(birth.time.timeIntervalSince(start))) of labor · ^[\(birth.contractions) contraction](inflect: true) timed")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Button("Start over for a new labor", action: startOver).buttonStyle(.soft)
        }
    }
}

/// Weeks, due date, term and this week's tip; the get-ready checklist folds below.
struct PregnancyCard: View {
    let profile: LaborProfile
    let now: Date
    let toggle: (PrepItem) -> Void
    let addDueDate: () -> Void
    @State private var showsChecklist = false

    var body: some View {
        let items = PrepItem.items(firstBaby: profile.settings.firstBaby)
        let done = items.filter(profile.isDone).count
        Card {
            if let p = Pregnancy(settings: profile.settings, now: now) {
                HStack(alignment: .firstTextBaseline) {
                    Text(p.weeksText).font(.system(.title2, design: .rounded, weight: .bold))
                    Text(p.term.title)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .foregroundStyle(p.term == .preterm ? Theme.Tone.warn : Color.accentColor)
                        .background((p.term == .preterm ? Theme.Tone.warn : Color.accentColor).opacity(0.12), in: Capsule())
                    Spacer()
                }
                Text(p.dueText + " · " + (profile.settings.dueDate?.formatted(date: .abbreviated, time: .omitted) ?? ""))
                    .font(.subheadline).foregroundStyle(.secondary)
                Text(p.tip).font(.subheadline).fixedSize(horizontal: false, vertical: true)
            } else {
                Button("Add the due date to see the weeks and what to get ready", action: addDueDate)
                    .font(.subheadline)
                Text("Without it the app can't tell preterm contractions (before 37 weeks).")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Button {
                withAnimation(.snappy) { showsChecklist.toggle() }
            } label: {
                HStack {
                    Text("Get ready").font(.subheadline.weight(.semibold))
                    Text("\(done) of \(items.count)").font(.subheadline).foregroundStyle(done == items.count ? Theme.Tone.good : .secondary)
                    Spacer()
                    Image(systemName: "chevron.right").rotationEffect(.degrees(showsChecklist ? 90 : 0)).foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if showsChecklist {
                ForEach(items, id: \.self) { item in
                    let isOn = profile.isDone(item)
                    Button { toggle(item) } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isOn ? Theme.Tone.good : .secondary)
                            Text(item.title).font(.subheadline).strikethrough(isOn, color: .secondary)
                                .foregroundStyle(isOn ? .secondary : .primary)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
        }
    }
}
