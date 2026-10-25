import SwiftUI

/// One plain answer, one big button, three numbers against their goals; everything else behind Details.
struct LaborView: View {
    @Stored(LaborStore.profilesKey) private var profiles: [LaborProfile] = []
    @Stored(LaborStore.currentKey) private var currentID = ""

    @State private var editing: Contraction?
    @State private var editingEvent: LaborEvent?
    @State private var toast: Toast?
    @State private var starts = 0
    @State private var stops = 0
    @State private var showsSettings = false
    @State private var showsDetails = false
    @State private var showsGuide = false
    @State private var showsSetup = false
    @State private var picksEvent = false
    @State private var asksFluid = false
    @State private var writesNote = false
    @State private var note = ""
    @State private var lastTap = Date.distantPast
    @State private var confirmsBirth = false
    /// A stage tapped to read about; recorded only on "We're here now".
    @State private var previewing: LaborStage?
    @Environment(\.openURL) private var openURL

    private struct Toast: Equatable {
        let text: String
        let undo: () -> Void
        let id = UUID()
        static func == (a: Toast, b: Toast) -> Bool { a.id == b.id }
    }

    var body: some View {
        // Seconds only matter while a contraction runs.
        TimelineView(.periodic(from: .now, by: contractions.contains { $0.end == nil } ? 1 : 30)) { context in
            let analysis = LaborAnalysis(profile: profile, now: context.date)
            List {
                Group {
                    ForEach(analysis.flags) { flag in
                        FlagBanner(flag: flag, phone: flag.isEmergency ? settings.emergency : settings.phone,
                                   call: { flag.isEmergency ? dial(settings.emergency) : call() }, setNumber: { showsSettings = true })
                    }
                    if !settings.setupDone {
                        SetupPrompt(skipped: settings.setupSkipped, start: { showsSetup = true }, skip: { settings.setupSkipped = true })
                    }
                    if settings.phone.isEmpty && analysis.flags.isEmpty && analysis.stage < .hospital && settings.setupDone {
                        Button { showsSettings = true } label: {
                            Label("Add the hospital's number", systemImage: "phone.badge.plus").font(.subheadline)
                        }
                        .buttonStyle(.soft)
                    }
                    if analysis.stage < .hospital {
                        PregnancyCard(profile: profile, now: context.date, toggle: togglePrep, addDueDate: { showsSettings = true })
                    }
                    StageBar(stage: analysis.stage, previewing: previewing) { previewing = $0 == analysis.stage ? nil : $0 }
                    if let previewing {
                        StagePreview(stage: previewing, current: analysis.stage,
                                     back: { self.previewing = nil }, confirm: { confirm(previewing) })
                        StageCard(stage: previewing, rule: settings.rule, isPreview: true)
                    }
                    if let next = suggestion(analysis) {
                        StageSuggestion(stage: next, reason: next == .active ? "Your hospital rule (\(settings.rule.name)) is met." : "Contractions are regular now.",
                                        accept: { setStage(next) }, dismiss: { update { $0.notYet = StageDismissal(stage: next, at: .now) } })
                    }
                    if let birth = analysis.birth {
                        BirthCard(birth: birth, startOver: startNewLabor)
                    } else {
                        if contractions.isEmpty { LaborGuide() }
                        if !analysis.episode.isEmpty && analysis.stage < .hospital {
                            AdviceView(advice: analysis.advice, phone: settings.phone, call: call, setNumber: { showsSettings = true })
                        }
                        bigButton(analysis)
                        afterButton(analysis)
                        if !analysis.episode.isEmpty && analysis.stage < .hospital {
                            GoalRow(check: analysis.ruleCheck, firstSign: !settings.plan.firstSign.isEmpty)
                        }
                        actions(analysis)
                    }
                    if previewing == nil { StageCard(stage: analysis.stage, rule: settings.rule) }
                }
                .laborRow()

                LaborHistory(analysis: analysis, contractions: contractions, events: events,
                             edit: { editing = $0 }, editEvent: { editingEvent = $0 }, delete: delete)
            }
            .toolbar { toolbar(analysis) }
            .sheet(isPresented: $showsDetails) { LaborDetails(analysis: analysis) }
            // Keep the screen on only while a labor is being timed.
            .onChange(of: analysis.episode.isEmpty, initial: true) { _, idle in UIApplication.shared.isIdleTimerDisabled = !idle }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .navigationTitle(profile.name.isEmpty ? AppTool.labor.title : profile.name)
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.impact(weight: .heavy), trigger: starts)
        .sensoryFeedback(.impact(weight: .medium), trigger: stops)
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .overlay(alignment: .bottom) { toastView }
        .sheet(item: $editing) { contraction in
            ContractionEditor(contraction: contraction, others: contractions, save: { replace($0) }, delete: { delete([contraction.id]) })
        }
        .sheet(item: $editingEvent) { event in
            LaborEventEditor(event: event, save: { new in events = events.map { $0.id == new.id ? new : $0 } }, delete: { delete([event.id]) })
        }
        .sheet(isPresented: $showsGuide) {
            ScrollView { LaborGuide().padding() }.presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showsSetup) { LaborSetup(settings: settingsBinding) }
        .sheet(isPresented: $showsSettings) { LaborSettingsSheet(settings: settingsBinding, clearAll: clearAll) }
        .confirmationDialog("What happened?", isPresented: $picksEvent, titleVisibility: .visible) {
            Button("Waters broke…") { asksFluid = true }
            Button("Bleeding") { add(.bleeding) }
            Button("Mucus plug / show") { add(.show) }
            Button("Baby moving less") { add(.lessMovement) }
            Button("She rested or drank water") { add(.rested) }
            Button("Baby coming: urge to push, or cord visible") { add(.pushing) }
            Button("Write a note…") { writesNote = true }
        } message: {
            Text("Saved with the time. \"Rested\" helps tell practice contractions from labor.")
        }
        .confirmationDialog("What colour was the water?", isPresented: $asksFluid, titleVisibility: .visible) {
            ForEach(LaborEvent.Fluid.allCases, id: \.self) { fluid in
                Button(fluid.title) { add(.waters, fluid: fluid) }
            }
        }
        .confirmationDialog("Baby is born?", isPresented: $confirmsBirth, titleVisibility: .visible) {
            Button("Yes — save the birth time now") { setStage(.born) }
        } message: {
            Text("Ends this labor. Everything stays in the timeline.")
        }
        .alert("Note", isPresented: $writesNote) {
            TextField("What happened", text: $note)
            Button("Cancel", role: .cancel) { note = "" }
            Button("Add") {
                add(.note, text: note.trimmingCharacters(in: .whitespacesAndNewlines))
                note = ""
            }
        }
    }

    // MARK: Button

    private func bigButton(_ analysis: LaborAnalysis) -> some View {
        let open = analysis.open
        return Button { toggle(analysis) } label: {
            VStack(spacing: 6) {
                if let open {
                    Text("Contraction in progress").font(.headline)
                    Text(LaborAnalysis.clock(analysis.now.timeIntervalSince(open.start)))
                        .font(.clock(64, weight: .medium))
                        .contentTransition(.numericText())
                    Text("Tap when it ends").font(.title3.weight(.bold))
                } else {
                    Image(systemName: "hand.tap.fill").font(.system(size: 34))
                    Text("Tap when a contraction starts").font(.title3.weight(.bold))
                }
            }
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 180)
            .background(open != nil ? Theme.Tone.bad : Color.accentColor,
                        in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 32))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func afterButton(_ analysis: LaborAnalysis) -> some View {
        if let open = analysis.open {
            HStack {
                if analysis.now.timeIntervalSince(open.start) > LaborAnalysis.maxLength {
                    Text("Forgot to tap?").font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Button("End it at 1:00") { stop(open, at: open.start.addingTimeInterval(60)) }.buttonStyle(.soft)
                } else {
                    Spacer()
                }
                Button("Tapped by mistake", role: .destructive) { delete([open.id]) }.buttonStyle(.soft)
            }
        } else if let last = analysis.last, let end = last.end {
            VStack(alignment: .leading, spacing: 10) {
                Text(lastLine(last, analysis: analysis))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if analysis.now.timeIntervalSince(end) < 15 * 60 { strengthPicker(last) }
            }
        }
    }

    /// Minute steps: the page only ticks every 30 s between contractions.
    private func lastLine(_ last: Contraction, analysis: LaborAnalysis) -> String {
        let minutes = Int(analysis.now.timeIntervalSince(last.start) / 60)
        let ago = minutes < 1 ? "just now" : "\(LaborAnalysis.span(TimeInterval(minutes * 60))) ago"
        let lasted = last.length.map { ", lasted \(LaborAnalysis.clock($0))" } ?? ""
        return "Last one started \(ago)\(lasted)."
    }

    private func strengthPicker(_ last: Contraction) -> some View {
        let chips = ForEach(Contraction.Strength.allCases, id: \.self) { strength in
            let isOn = last.strength == strength
            Button(strength.title) {
                var updated = last
                updated.strength = isOn ? nil : strength
                replace(updated)
            }
            .buttonStyle(LaborChip(isOn: isOn))
        }
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                Text("How strong?").font(.subheadline).fixedSize()
                chips
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("How strong?").font(.subheadline)
                HStack(spacing: 8) { chips }
            }
        }
    }

    private func actions(_ analysis: LaborAnalysis) -> some View {
        HStack(spacing: 10) {
            Button { picksEvent = true } label: {
                Label("Waters, bleeding, other…", systemImage: "plus.circle").frame(maxWidth: .infinity)
            }
            if !analysis.episode.isEmpty {
                Button { showsDetails = true } label: {
                    Label("Details", systemImage: "chart.xyaxis.line").frame(maxWidth: .infinity)
                }
            }
        }
        .buttonStyle(.soft)
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private func toolbar(_ analysis: LaborAnalysis) -> some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button { showsGuide = true } label: { Label("How to use", systemImage: "info.circle") }
            ShareLink(item: analysis.summary()) { Label("Send summary", systemImage: "square.and.arrow.up") }
                .disabled(analysis.episode.isEmpty && events.isEmpty)
            Button { showsSettings = true } label: { Label("Settings", systemImage: "gearshape") }
        }
    }

    // MARK: Profiles

    /// The chosen labor; the first one stands in when none is chosen or saved yet.
    private var profile: LaborProfile {
        LaborStore.current(in: profiles, id: currentID)
    }

    private func update(_ change: (inout LaborProfile) -> Void) {
        var current = profile
        change(&current)
        var all = profiles
        if let i = all.firstIndex(where: { $0.id == current.id }) { all[i] = current } else { all.insert(current, at: 0) }
        profiles = all
        currentID = current.id.uuidString
    }

    private var contractions: [Contraction] {
        get { profile.contractions }
        nonmutating set { update { $0.contractions = newValue } }
    }

    private var events: [LaborEvent] {
        get { profile.events }
        nonmutating set { update { $0.events = newValue } }
    }

    private var settings: LaborSettings {
        get { profile.settings }
        nonmutating set { update { $0.settings = newValue } }
    }

    private var settingsBinding: Binding<LaborSettings> {
        Binding(get: { settings }, set: { settings = $0 })
    }

    /// The plan and phone items tick themselves from settings; tapping them opens where they're set.
    private func togglePrep(_ item: PrepItem) {
        let p = profile
        if item == .plan, !p.settings.setupDone { showsSetup = true; return }
        if p.isDone(item), !p.prep.contains(item) { showsSettings = true; return }
        if item == .phone, !p.isDone(item) { showsSettings = true; return }
        update { if $0.prep.contains(item) { $0.prep.remove(item) } else { $0.prep.insert(item) } }
    }

    // MARK: Stage

    /// Hidden for 30 min after "Not yet".
    private func suggestion(_ analysis: LaborAnalysis) -> LaborStage? {
        guard let next = analysis.suggestedStage else { return nil }
        if let notYet = profile.notYet, notYet.stage == next, analysis.now.timeIntervalSince(notYet.at) < 30 * 60 { return nil }
        return next
    }

    private func confirm(_ stage: LaborStage) {
        previewing = nil
        if stage == .born { confirmsBirth = true } else { setStage(stage) }
    }

    private func setStage(_ stage: LaborStage) {
        let analysis = LaborAnalysis(profile: profile, now: .now)
        guard stage != analysis.stage else { return }
        if stage == .born, let open = analysis.open { stop(open, at: .now) }
        update {
            $0.notYet = nil
            $0.events.append(LaborEvent(kind: .stage, time: .now, stage: stage))
        }
    }

    /// A fresh profile; the finished labor stays in Settings › Labors.
    private func startNewLabor() {
        let added = LaborStore.adding(after: profile, to: profiles)
        profiles = added.profiles
        currentID = added.next.id.uuidString
    }

    // MARK: Changes

    private func toggle(_ analysis: LaborAnalysis) {
        let now = Date.now
        guard now.timeIntervalSince(lastTap) > 0.5 else { return }
        lastTap = now
        if let open = analysis.open {
            stop(open, at: now)
            stops += 1
        } else {
            contractions.append(Contraction(start: now))
            starts += 1
        }
    }

    private func stop(_ contraction: Contraction, at time: Date) {
        var stopped = contraction
        stopped.end = max(contraction.start, time)
        replace(stopped)
    }

    private func replace(_ contraction: Contraction) {
        contractions = contractions.map { $0.id == contraction.id ? contraction : $0 }
    }

    private func delete(_ ids: [UUID]) {
        let before = profile
        let gone = Set(ids)
        update {
            $0.contractions.removeAll { gone.contains($0.id) }
            $0.events.removeAll { gone.contains($0.id) }
        }
        let text = ids.count == 1 ? "Deleted" : "Deleted \(ids.count)"
        withAnimation(.snappy) {
            toast = Toast(text: text) { update { $0.contractions = before.contractions; $0.events = before.events } }
        }
    }

    @ViewBuilder
    private var toastView: some View {
        if let toast {
            HStack(spacing: 14) {
                Text(toast.text).font(.label)
                Button("Undo") { toast.undo(); withAnimation(.snappy) { self.toast = nil } }
                    .font(.label.weight(.bold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
            .padding(.bottom, 24)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .task(id: toast) {
                try? await Task.sleep(for: .seconds(4))
                guard !Task.isCancelled else { return }
                withAnimation(.snappy) { self.toast = nil }
            }
        }
    }

    private func add(_ kind: LaborEvent.Kind, fluid: LaborEvent.Fluid? = nil, text: String? = nil) {
        if kind == .note && (text ?? "").isEmpty { return }
        events.append(LaborEvent(kind: kind, time: .now, fluid: fluid, text: text))
    }

    private func clearAll() {
        contractions = []
        events = []
    }

    private func call() { dial(settings.phone) }

    private func dial(_ number: String) {
        guard let url = Self.telURL(number) else { showsSettings = true; return }
        openURL(url)
    }

    /// ASCII digits plus + * # and "," (pause before an extension); nil when there are no digits.
    static func telURL(_ number: String) -> URL? {
        let kept = number.filter { ("0"..."9").contains($0) || "+*#,".contains($0) }
        guard kept.contains(where: { ("0"..."9").contains($0) }),
              let encoded = kept.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "0123456789+*,")) else { return nil }
        return URL(string: "tel:\(encoded)")
    }
}

extension View {
    func laborRow() -> some View {
        listRowInsets(EdgeInsets(top: 8, leading: Theme.padding, bottom: 8, trailing: Theme.padding))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

#Preview {
    NavigationStack { LaborView() }
}
