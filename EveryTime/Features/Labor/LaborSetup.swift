import SwiftUI

/// One question per page; Next keeps what's shown, the due-date page can be left blank. Answers save as you go; the last page reads the plan back.
struct LaborSetup: View {
    @Binding var settings: LaborSettings
    @Environment(\.dismiss) private var dismiss
    @State private var step = Step.baby

    enum Step: Int, CaseIterable {
        case baby, due, hospital, travel, health, careTeam, plan
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                ProgressView(value: Double(step.rawValue + 1), total: Double(Step.allCases.count))
                    .padding(.horizontal, Theme.padding)
                Text("Step \(step.rawValue + 1) of \(Step.allCases.count)")
                    .font(.footnote).foregroundStyle(.secondary)
                    .padding(.horizontal, Theme.padding).padding(.top, 6)
                ScrollView {
                    page.frame(maxWidth: .infinity, alignment: .leading).padding(Theme.padding)
                }
                bottomButtons
            }
            .navigationTitle("Set up your labor plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .animation(.snappy, value: step)
        }
        .interactiveDismissDisabled()
    }

    // MARK: Pages

    @ViewBuilder
    private var page: some View {
        switch step {
        case .baby:
            question("Is this your first baby?", hint: "Labor is usually longer with a first baby, and faster with later ones.")
            choice("Yes, first baby", isOn: settings.firstBaby) { settings.firstBaby = true; settings.fastLastLabor = false }
            choice("No, we've had a baby before", isOn: !settings.firstBaby) { settings.firstBaby = false }
            if !settings.firstBaby {
                question("Was a previous labor under 3 hours?", hint: "A fast labor before means this one may be fast too, so you go earlier.")
                    .padding(.top, 20)
                choice("Yes, it was fast", isOn: settings.fastLastLabor) { settings.fastLastLabor = true }
                choice("No / not sure", isOn: !settings.fastLastLabor) { settings.fastLastLabor = false }
            }
        case .due:
            question("When is the baby due?", hint: "Before 37 weeks, contractions are worth a call — the app needs the date to know.")
            DatePicker("Due date", selection: dueDate, in: LaborSettings.dueRange(), displayedComponents: .date)
                .datePickerStyle(.graphical)
            if let g = LaborSettings.gestation(due: dueDate.wrappedValue) {
                Text("Today: " + Pregnancy.weeksText(weeks: g.weeks, days: g.days)).font(.headline)
            }
        case .hospital:
            question("Which hospital, and its labor phone?", hint: "Use the number for labor and delivery (triage), not the main switchboard. Every Call button dials it.")
            field("Hospital or birth center", text: $settings.hospital)
            field("Labor and delivery phone", text: $settings.phone, phone: true)
            field("Emergency number", text: $settings.emergency, phone: true)
            Text("Emergency is for when the baby is coming before you can get there.")
                .font(.footnote).foregroundStyle(.secondary)
        case .travel:
            question("How long does it take to get there?", hint: "Door to door, at night. Far away means you leave earlier.")
            HStack {
                ForEach([10, 20, 30, 45, 60], id: \.self) { minutes in
                    Button("\(minutes)\(minutes == 60 ? "+" : "") min") { settings.travelMinutes = minutes }
                        .buttonStyle(LaborChip(isOn: settings.travelMinutes == minutes))
                }
            }
            Stepper(settings.travelMinutes == 0 ? "Not set" : "About \(settings.travelMinutes) min", value: $settings.travelMinutes, in: 0...240, step: 5)
                .font(.headline)
            question("How will you get there?", hint: "Taxis and pick-ups add about 15 min of waiting. She shouldn't drive herself.")
                .padding(.top, 20)
            ForEach(LaborSettings.Transport.allCases, id: \.self) { t in
                choice(t.title, isOn: settings.transport == t) { settings.transport = t }
            }
        case .health:
            question("Does any of this apply?", hint: "Tick all that fit. With these, care teams usually want a call at the first contractions or when waters break (RCOG, NHS). Ask yours to be sure.")
            ForEach(LaborSettings.Condition.allCases, id: \.self) { c in
                let isOn = settings.conditions.contains(c)
                choice(c.title, isOn: isOn, multi: true) {
                    if isOn { settings.conditions.remove(c) } else { settings.conditions.insert(c) }
                }
            }
            choice("None of these", isOn: settings.conditions.isEmpty, multi: true) { settings.conditions = [] }
        case .careTeam:
            question("Did your care team tell you when to call?", hint: "Their advice beats any app. If they gave you a rule, enter it here.")
            choice("No — use the app's plan", isOn: settings.careTeamRule == nil) { settings.careTeamRule = nil }
            choice("Yes, they gave us a rule", isOn: settings.careTeamRule != nil) {
                if settings.careTeamRule == nil { settings.careTeamRule = settings.plan.rule }
            }
            if settings.careTeamRule != nil { RuleSteppers(rule: careTeamRule).padding(.top, 8) }
        case .plan:
            question("Your plan", hint: "You can change any answer later in ⚙.")
            Text(settings.planSentence)
                .font(.title3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(16)
                .background(Theme.cardFill, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            Text("Whatever the plan says, it's fine to call if waters break, there's bleeding, the baby moves less, or anything feels off.")
                .font(.subheadline).foregroundStyle(.secondary)
            if settings.phone.isEmpty {
                Label("No hospital phone yet — Call buttons will ask for it.", systemImage: "exclamationmark.triangle")
                    .font(.subheadline).foregroundStyle(Theme.Tone.warn)
            }
        }
    }

    private var bottomButtons: some View {
        HStack {
            if step != .baby {
                Button("Back") { step = Step(rawValue: step.rawValue - 1) ?? .baby }.buttonStyle(.soft)
            }
            Spacer()
            if step == .plan {
                Button("Done") { settings.setupDone = true; dismiss() }.buttonStyle(.borderedProminent).controlSize(.large)
            } else {
                if step == .due {
                    Button("Don't know yet") { settings.dueDate = nil; advance() }.buttonStyle(.soft)
                }
                Button("Next") {
                    if step == .due { settings.dueDate = dueDate.wrappedValue }
                    advance()
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
            }
        }
        .padding(Theme.padding)
        .background(.bar)
    }

    private func advance() { step = Step(rawValue: step.rawValue + 1) ?? .plan }

    // MARK: Parts

    private func question(_ title: String, hint: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(.title2, design: .rounded, weight: .bold))
            Text(hint).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 12)
    }

    private func choice(_ title: String, isOn: Bool, multi: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: isOn ? (multi ? "checkmark.square.fill" : "checkmark.circle.fill") : (multi ? "square" : "circle"))
                    .foregroundStyle(isOn ? Color.accentColor : .secondary)
            }
            .font(.body)
            .padding(14)
            .frame(minHeight: 52)
            .background(isOn ? Color.accentColor.opacity(0.12) : Theme.cardFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.bottom, 8)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func field(_ title: String, text: Binding<String>, phone: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.footnote).foregroundStyle(.secondary)
            TextField(title, text: text)
                .keyboardType(phone ? .phonePad : .default)
                .textContentType(phone ? .telephoneNumber : .organizationName)
                .padding(12)
                .background(Theme.cardFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(.bottom, 12)
    }

    private var dueDate: Binding<Date> {
        Binding(get: { settings.dueDate ?? LaborSettings.suggestedDueDate }, set: { settings.dueDate = $0 })
    }

    private var careTeamRule: Binding<LaborRule> {
        Binding(get: { settings.careTeamRule ?? settings.plan.rule }, set: { settings.careTeamRule = $0 })
    }
}

/// Every / lasting / for steppers for a go rule.
struct RuleSteppers: View {
    @Binding var rule: LaborRule

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Stepper("Every \(Int(rule.interval / 60)) min or closer", value: $rule.interval, in: 60...20 * 60, step: 60)
            Stepper("Each lasting \(LaborAnalysis.clock(rule.length)) or more", value: $rule.length, in: 20...120, step: 5)
            Stepper("For \(LaborAnalysis.span(rule.window))", value: $rule.window, in: 15 * 60...3 * 3600, step: 15 * 60)
        }
    }
}
