import SwiftUI

/// Nap timer with a wake alarm, advice on when and how long, and a log rated by how the night went.
struct NapView: View {
    @Stored(JetLagKey.profile) private var profile: JetLagProfile? = nil
    @Stored(NapKey.naps) private var naps: [Nap] = []
    @Stored(NapKey.active) private var active: ActiveNap? = nil
    @Stored(NapKey.length) private var length = NapAdvice.suggestedMinutes
    @Stored(NapKey.night) private var plan: NightPlan? = nil
    @State private var sheet: SheetKind?
    @State private var openField: NightField?

    private enum NightField { case bed, wake }

    private enum SheetKind: String, Identifiable {
        case profile, log
        var id: String { rawValue }
    }

    private var advice: NapAdvice { NapAdvice(profile: profile ?? JetLagProfile(), plan: plan) }

    private var todayPlan: NightPlan? {
        plan.flatMap { Calendar.current.isDateInToday($0.day) ? $0 : nil }
    }

    var body: some View {
        TimelineView(.everyMinute) { context in
            let now = context.date
            List {
                Section {
                    Group {
                        if let active { NapInProgress(nap: active, advice: advice) } else { planner(now: now) }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: Theme.padding, bottom: 20, trailing: Theme.padding))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                if let nap = unratedNap(now: now) {
                    Section { ratePrompt(nap).napRow() } header: { SectionLabel("Last nap").textCase(nil) }
                }
                if naps.filter({ $0.night != nil }).count >= 3 {
                    Section { pattern.napRow() } header: { SectionLabel("Your nights after naps").textCase(nil) }
                }
                history
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .animation(.snappy, value: naps)
        .animation(.snappy, value: active)
        .navigationTitle(AppTool.nap.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Log a nap", systemImage: "plus") { sheet = .log }
            }
        }
        .bottomBar { bottomBar }
        .sheet(item: $sheet) { kind in
            switch kind {
            case .profile:
                JetLagProfileSheet(profile: profile ?? JetLagProfile(), showsAdvice: false) { profile = $0 }
            case .log:
                LogNapSheet { naps.insert($0, at: 0); naps.sort { $0.start > $1.start } }
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: active == nil)
        .sensoryFeedback(.selection, trigger: length)
    }

    // MARK: Planner

    private func planner(now: Date) -> some View {
        let window = advice.window(on: now)
        let suggested = advice.suggestedMinutes(on: now)
        return VStack(alignment: .leading, spacing: Theme.spacing) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel("Best time to nap")
                InfoButton(label: "About naps", text: NapAdvice.info)
            }
            Text("\(window.start.formatted(date: .omitted, time: .shortened)) – \(window.end.formatted(date: .omitted, time: .shortened))")
                .font(.clock(34, weight: .regular))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text("\(suggested) min, starting by \(window.end.formatted(date: .omitted, time: .shortened))")
                .font(.subheadline).foregroundStyle(.secondary)

            tonightCard(now: now)

            Card {
                Text("If you nap now for")
                    .font(.cardTitle)
                lengthPills
                EffectRow(symbol: "moon.zzz", text: NapAdvice.tonightText(advice.tonight(start: now, minutes: length)),
                          level: advice.tonight(start: now, minutes: length))
                EffectRow(symbol: "alarm", text: NapAdvice.wakeText(minutes: length),
                          level: NapAdvice.grogginess(minutes: length))
            }
            .padding(.top, 4)

            Button { sheet = .profile } label: {
                HStack(spacing: 6) {
                    Image(systemName: "person.crop.circle")
                    Text(profileSummary)
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                }
                .font(.label)
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private func tonightCard(now: Date) -> some View {
        let day = advice.day(of: now)
        return Card {
            HStack {
                Text("Tonight").font(.cardTitle)
                Spacer()
                if todayPlan != nil {
                    Button("Use usual") { withAnimation(.snappy) { plan = nil } }
                        .font(.label)
                        .buttonStyle(.borderless)
                }
            }
            timeRow("Bed", .bed, minutes: planBinding(\.bed))
            timeRow("Wake tomorrow", .wake, minutes: planBinding(\.wake))
            Text("\(NapAdvice.hours(day.nightHours)) of sleep")
                .font(.label).foregroundStyle(.secondary)
            if let note = advice.nightNote(on: now) {
                Label(note, systemImage: "lightbulb")
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func timeRow(_ title: String, _ field: NightField, minutes: Binding<Int>) -> some View {
        UnfoldingRow(id: field, open: $openField) {
            Text(title)
        } value: {
            Text(minutes.wrappedValue.timeOfDayText).monospacedDigit()
        } picker: {
            DatePicker(title, selection: minutes.timeOfDay, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderless)
    }

    /// Edits today's plan, starting from the usual hours.
    private func planBinding(_ field: WritableKeyPath<NightPlan, Int>) -> Binding<Int> {
        let usual = profile ?? JetLagProfile()
        let current = todayPlan ?? NightPlan(day: Calendar.current.startOfDay(for: .now), bed: usual.usualBedtime, wake: usual.usualWake)
        return Binding {
            current[keyPath: field]
        } set: { value in
            var edited = current
            edited[keyPath: field] = value
            plan = edited.bed == usual.usualBedtime && edited.wake == usual.usualWake ? nil : edited
        }
    }

    private var lengthPills: some View {
        HStack(spacing: 8) {
            ForEach(NapAdvice.lengths, id: \.self) { minutes in
                let isSelected = minutes == length
                Button("\(minutes) min") { length = minutes }
                    .font(.label)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 34)
                    .background(isSelected ? Color.accentColor.opacity(0.15) : Theme.cardFill, in: Capsule())
                    .contentShape(Capsule())
                    .buttonStyle(.plain)
            }
        }
    }

    private var profileSummary: String {
        guard let profile else { return "Set your usual sleep and age" }
        return "\(profile.usualBedtime.timeOfDayText) → \(profile.usualWake.timeOfDayText) · age \(profile.age)"
    }

    @ViewBuilder
    private var bottomBar: some View {
        if let active {
            HStack(spacing: Theme.spacing) {
                Button("Cancel") {
                    NapAlarm.cancel()
                    self.active = nil
                }
                .buttonStyle(.soft)
                Button("I'm up") { finish(active) }
                    .buttonStyle(.primary)
            }
        } else {
            Button {
                let nap = ActiveNap(start: .now, minutes: length)
                active = nap
                Task { await NapAlarm.schedule(nap) }
            } label: {
                Label("Nap \(length) min · wake at \(Date.now.addingTimeInterval(Double(length) * 60).formatted(date: .omitted, time: .shortened))",
                      systemImage: "powersleep")
            }
            .buttonStyle(.primary)
        }
    }

    private func finish(_ nap: ActiveNap) {
        NapAlarm.cancel()
        naps.insert(Nap(start: nap.start, end: .now, bed: todayPlan == nil ? nil : advice.day(of: nap.start).bed), at: 0)
        active = nil
    }

    // MARK: Nights

    private func unratedNap(now: Date) -> Nap? {
        naps.first { nap in
            nap.night == nil && !Calendar.current.isDate(nap.start, inSameDayAs: now)
                && now.timeIntervalSince(nap.start) < 3 * 86_400
        }
    }

    private func ratePrompt(_ nap: Nap) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How was the night after \(nap.start.formatted(.dateTime.weekday(.wide)))'s \(nap.minutes)-minute nap at \(nap.start.formatted(date: .omitted, time: .shortened))?")
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

    /// Nights grouped by the effect the advice predicted, so the rules can be checked against you.
    private var pattern: some View {
        let rated = naps.filter { $0.night != nil }
        return VStack(alignment: .leading, spacing: 8) {
            ForEach([NapAdvice.Level.low, .some, .high], id: \.self) { level in
                let group = rated.filter { advice.tonight(start: $0.start, minutes: $0.minutes, bed: $0.bed) == level }
                if !group.isEmpty {
                    HStack {
                        Circle().fill(level.tint).frame(width: 8, height: 8)
                        Text(NapAdvice.tonightText(level)).font(.subheadline)
                        Spacer()
                        Text("\(group.filter { $0.night == .good }.count) of \(group.count) good")
                            .font(.label).monospacedDigit().foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func rate(_ nap: Nap, _ night: Nap.Night?) {
        guard let i = naps.firstIndex(where: { $0.id == nap.id }) else { return }
        naps[i].night = night
    }

    // MARK: History

    private var history: some View {
        Section {
            if naps.isEmpty {
                Text("No naps yet — start one, or log a past nap with +")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .napRow()
            }
            ForEach(naps) { nap in
                NapRow(nap: nap, level: advice.tonight(start: nap.start, minutes: nap.minutes, bed: nap.bed))
                    .napRow()
                    .contextMenu {
                        ForEach(Nap.Night.allCases) { night in
                            Button(night.title, systemImage: night.symbol) { rate(nap, night) }
                        }
                        if nap.night != nil {
                            Button("Clear rating", systemImage: "xmark") { rate(nap, nil) }
                        }
                    }
            }
            .onDelete { naps.remove(atOffsets: $0) }
        } header: {
            SectionLabel("History").textCase(nil)
        }
    }
}

private struct NapInProgress: View {
    let nap: ActiveNap
    let advice: NapAdvice

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = nap.alarm.timeIntervalSince(context.date)
            VStack(spacing: 6) {
                TimerCaption(text: "Napping since \(nap.start.formatted(date: .omitted, time: .shortened))")
                Text(TimeText.countdown(remaining))
                    .timerDigits()
                    .foregroundStyle(remaining > 0 ? Color.primary : Theme.Tone.warn)
                    .contentTransition(.numericText())
                TimerCaption(text: remaining > 0 ? "Alarm at \(nap.alarm.formatted(date: .omitted, time: .shortened))" : "Time to get up",
                             tint: remaining > 0 ? nil : Theme.Tone.warn)
                EffectRow(symbol: "moon.zzz", text: NapAdvice.tonightText(advice.tonight(start: nap.start, minutes: nap.minutes)),
                          level: advice.tonight(start: nap.start, minutes: nap.minutes))
                    .padding(.top, 16)
            }
            .frame(maxWidth: .infinity)
            .sensoryFeedback(.warning, trigger: remaining <= 0)
        }
    }
}

private struct EffectRow: View {
    let symbol: String
    let text: String
    let level: NapAdvice.Level

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).foregroundStyle(level.tint).frame(width: 22)
            Text(text).font(.subheadline)
        }
    }
}

private struct NapRow: View {
    let nap: Nap
    let level: NapAdvice.Level

    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(level.tint).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 3) {
                Text(nap.start, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                    .font(.system(.body, design: .rounded))
                Text("\(nap.start.formatted(date: .omitted, time: .shortened)) – \(nap.end.formatted(date: .omitted, time: .shortened))")
                    .font(.label)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let night = nap.night {
                Image(systemName: night.symbol)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(night.title)
            }
            Text("\(nap.minutes) min")
                .font(.clock(20, weight: .regular))
        }
    }
}

private struct LogNapSheet: View {
    let onSave: (Nap) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var start = Calendar.current.date(byAdding: .minute, value: -30, to: .now) ?? .now
    @State private var minutes = NapAdvice.suggestedMinutes

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Fell asleep", selection: $start, in: ...Date.now)
                Stepper("\(minutes) min", value: $minutes, in: 5...240, step: 5)
                    .monospacedDigit()
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Log a nap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .bottomBar {
                Button("Save") {
                    onSave(Nap(start: start, end: start.addingTimeInterval(Double(minutes) * 60)))
                    dismiss()
                }
                .buttonStyle(.primary)
            }
        }
        .presentationDetents([.medium])
    }
}

private extension View {
    func napRow() -> some View {
        listRowInsets(EdgeInsets(top: 10, leading: Theme.padding, bottom: 10, trailing: Theme.padding))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

#Preview {
    NavigationStack { NapView() }
}
