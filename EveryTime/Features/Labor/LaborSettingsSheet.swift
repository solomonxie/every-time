import SwiftUI

/// The plan as one sentence on top, then every setup answer in plain words, each one tap to change.
struct LaborSettingsSheet: View {
    @Binding var settings: LaborSettings
    let clearAll: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var confirmsClear = false
    @State private var confirmsReset = false
    @State private var showsSetup = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(settings.planSentence).fixedSize(horizontal: false, vertical: true)
                    Button("Go through setup again") { showsSetup = true }
                } header: {
                    Text("Your plan")
                } footer: {
                    Text("Built from the answers below. Change any of them and the plan updates.")
                }

                LaborsSection()

                Section {
                    Picker("First baby?", selection: $settings.firstBaby) {
                        Text("Yes").tag(true)
                        Text("No").tag(false)
                    }
                    if !settings.firstBaby {
                        Toggle("A previous labor was under 3 hours", isOn: $settings.fastLastLabor)
                    }
                    Toggle("I know the due date", isOn: hasDueDate)
                    if let due = settings.dueDate {
                        DatePicker("Due date", selection: Binding(get: { due }, set: { settings.dueDate = $0 }),
                                   in: LaborSettings.dueRange(), displayedComponents: .date)
                        if let g = settings.gestation(at: .now) {
                            LabeledContent("Today", value: Pregnancy.weeksText(weeks: g.weeks, days: g.days))
                        }
                    }
                } header: {
                    Text("Baby")
                } footer: {
                    Text("Later babies and a fast last labor move the plan earlier. The due date shows the weeks and flags contractions before 37 weeks.")
                }

                Section {
                    TextField("Hospital or birth center", text: $settings.hospital)
                    LabeledContent("Labor phone") {
                        TextField("Not set", text: $settings.phone).keyboardType(.phonePad).multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Emergency") {
                        TextField("911", text: $settings.emergency).keyboardType(.phonePad).multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("Hospital")
                } footer: {
                    Text("Labor phone = labor and delivery (triage). Emergency is for when the baby is coming before you can get there.")
                }

                Section {
                    Stepper("Travel time: \(settings.travelMinutes == 0 ? "not set" : "\(settings.travelMinutes) min")",
                            value: $settings.travelMinutes, in: 0...240, step: 5)
                    Picker("Going by", selection: $settings.transport) {
                        ForEach(LaborSettings.Transport.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                } header: {
                    Text("Getting there")
                } footer: {
                    Text("Over \(LaborSettings.farMinutes) min including the wait for a ride, the plan goes earlier.")
                }

                Section {
                    ForEach(LaborSettings.Condition.allCases, id: \.self) { c in
                        Toggle(c.title, isOn: Binding(get: { settings.conditions.contains(c) },
                                                      set: { if $0 { settings.conditions.insert(c) } else { settings.conditions.remove(c) } }))
                    }
                } header: {
                    Text("Health")
                } footer: {
                    Text("Any of these: call at the first contractions or when waters break, without waiting for the rule. Confirm with your care team.")
                }

                Section {
                    Toggle("My care team gave me a rule", isOn: hasCareTeamRule)
                    if settings.careTeamRule != nil {
                        RuleSteppers(rule: Binding(get: { settings.careTeamRule ?? settings.plan.rule }, set: { settings.careTeamRule = $0 }))
                    }
                } header: {
                    Text("When to call")
                } footer: {
                    Text("Their rule replaces the app's. Otherwise: first baby 5-1-1; later baby 5 min apart, no full hour; fast last labor or over 30 min away, 10 min apart (INSPQ).")
                }

                Section {
                    Button("Reset plan settings", role: .destructive) { confirmsReset = true }
                    Button("Delete all contractions and events", role: .destructive) { confirmsClear = true }
                } footer: {
                    Text("Reset clears every answer above and starts setup again; your timeline stays. Both are kept in your iCloud Drive backups until the next one.")
                }
            }
            .navigationTitle("Labor settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .confirmationDialog("Delete every contraction and event?", isPresented: $confirmsClear, titleVisibility: .visible) {
                Button("Delete all", role: .destructive) { clearAll() }
            }
            .confirmationDialog("Reset every plan answer?", isPresented: $confirmsReset, titleVisibility: .visible) {
                Button("Reset and start setup", role: .destructive) {
                    settings = LaborSettings()
                    showsSetup = true
                }
            } message: {
                Text("Contractions and events are kept.")
            }
            .sheet(isPresented: $showsSetup) { LaborSetup(settings: $settings) }
        }
    }

    private var hasDueDate: Binding<Bool> {
        Binding(get: { settings.dueDate != nil }, set: { on in
            settings.dueDate = on ? LaborSettings.suggestedDueDate : nil
        })
    }

    private var hasCareTeamRule: Binding<Bool> {
        Binding(get: { settings.careTeamRule != nil }, set: { settings.careTeamRule = $0 ? settings.plan.rule : nil })
    }
}

/// One profile per labor: switch, add, rename, delete. Everything below it in Settings belongs to the chosen one.
private struct LaborsSection: View {
    @Stored(LaborStore.profilesKey) private var profiles: [LaborProfile] = []
    @Stored(LaborStore.currentKey) private var currentID = ""
    @State private var confirmsDelete = false

    private var current: LaborProfile { LaborStore.current(in: profiles, id: currentID) }

    var body: some View {
        Section {
            ForEach(profiles.isEmpty ? [current] : profiles) { p in
                Button { currentID = p.id.uuidString } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.name).foregroundStyle(.primary)
                            Text(detail(p)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if p.id == current.id { Image(systemName: "checkmark").foregroundStyle(Color.accentColor) }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(p.id == current.id ? .isSelected : [])
            }
            LabeledContent("Name") {
                TextField("Name", text: name).multilineTextAlignment(.trailing)
            }
            Button("Start a new labor", systemImage: "plus") { add() }
            if profiles.count > 1 {
                Button("Delete \"\(current.name)\"…", role: .destructive) { confirmsDelete = true }
            }
        } header: {
            Text("Labors")
        } footer: {
            Text("Each labor — one per pregnancy — keeps its own plan, contractions and events. Tap one to switch; everything below and the main screen show the one with ✓. A new labor keeps the hospital and travel details and asks the rest again.")
        }
        .confirmationDialog("Delete \"\(current.name)\" with all its contractions and events?", isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button("Delete this labor", role: .destructive) {
                let id = current.id
                profiles = profiles.filter { $0.id != id }
                currentID = profiles.last?.id.uuidString ?? ""
            }
        }
    }

    private func detail(_ p: LaborProfile) -> String {
        let count = p.contractions.filter { !LaborAnalysis.isMisTap($0) }.count
        return "Started \(p.created.formatted(date: .abbreviated, time: .omitted)) · " + LaborAnalysis.count(count, "contraction")
    }

    private var name: Binding<String> {
        Binding(get: { current.name }, set: { new in
            var all = profiles.isEmpty ? [current] : profiles
            guard let i = all.firstIndex(where: { $0.id == current.id }) else { return }
            all[i].name = new
            profiles = all
            currentID = all[i].id.uuidString
        })
    }

    private func add() {
        let added = LaborStore.adding(after: current, to: profiles)
        profiles = added.profiles
        currentID = added.next.id.uuidString
    }
}
