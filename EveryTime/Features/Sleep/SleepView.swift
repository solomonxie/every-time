import SwiftUI

enum SleepSection: String, CaseIterable, Identifiable {
    case cycles = "Cycles"
    case jetLag = "Jet lag"

    var id: Self { self }
}

struct SleepView: View {
    @AppStorage("sleep.section") private var section = SleepSection.cycles

    var body: some View {
        Group {
            switch section {
            case .cycles: CyclesView()
            case .jetLag: JetLagTripsView()
            }
        }
        .navigationTitle("Sleep")
    }
}

struct SleepSectionPicker: View {
    @AppStorage("sleep.section") private var section = SleepSection.cycles

    var body: some View {
        Picker("Section", selection: $section) {
            ForEach(SleepSection.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
    }
}

private struct CyclesView: View {
    @State private var mode: SleepMode = .wakeAt
    @State private var wakeTime = Calendar.current.date(bySettingHour: 6, minute: 30, second: 0, of: .now) ?? .now

    var body: some View {
        TimelineView(.everyMinute) { context in
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacing) {
                    SleepSectionPicker()
                    Picker("Mode", selection: $mode) {
                        ForEach(SleepMode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if mode == .wakeAt {
                        Card {
                            DatePicker("Wake up at", selection: $wakeTime, displayedComponents: .hourAndMinute)
                        }
                    }

                    SectionLabel(title: mode == .wakeAt ? "Go to bed at" : "Wake up at") {
                        InfoButton(label: "About sleep cycles", text: """
                            A sleep cycle is about 90 minutes. Waking between cycles feels easier. \
                            Includes ~15 minutes to fall asleep.
                            """)
                    }
                    .padding(.top, 8)

                    Card {
                        ForEach(suggestions(now: context.date)) { SuggestionRow(suggestion: $0) }
                    }
                }
                .screen()
                .padding(.vertical, 8)
            }
        }
    }

    private func suggestions(now: Date) -> [SleepSuggestion] {
        switch mode {
        case .wakeAt: SleepSuggestion.bedtimes(wakingAt: wakeTime)
        case .bedNow: SleepSuggestion.wakeTimes(goingToBedAt: now)
        }
    }
}

private struct SuggestionRow: View {
    let suggestion: SleepSuggestion

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(suggestion.time, format: .dateTime.hour().minute())
                .font(.clock(suggestion.isRecommended ? 34 : 26, weight: suggestion.isRecommended ? .regular : .light))
                .contentTransition(.numericText())
            Spacer()
            Text("\(suggestion.cycles) cycles · \(suggestion.hours.formatted(.number.precision(.fractionLength(0...1))))h")
                .font(.subheadline)
                .fontWeight(suggestion.isRecommended ? .semibold : .regular)
                .monospacedDigit()
        }
        .foregroundStyle(suggestion.isRecommended ? .primary : .secondary)
        .accessibilityElement(children: .combine)
        .accessibilityHint(suggestion.isRecommended ? "Recommended" : "")
    }
}

#Preview {
    NavigationStack { SleepView() }
}
