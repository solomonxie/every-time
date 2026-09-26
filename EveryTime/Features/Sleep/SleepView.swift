import SwiftUI

struct SleepView: View {
    @AppStorage("sleep.cycles.mode") private var mode = SleepMode.wakeAt
    @AppStorage("sleep.cycles.wake") private var wakeMinutes = 6 * 60 + 30
    @State private var editingWake = false

    var body: some View {
        TimelineView(.everyMinute) { context in
            let now = context.date
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacing) {
                    hero(now: now)
                    SectionLabel(title: mode == .wakeAt ? "Go to bed at" : "Wake up at") {
                        InfoButton(label: "About sleep cycles", text: """
                            A sleep cycle is about 90 minutes. Waking between cycles feels easier. \
                            5–6 cycles is a full night. Includes ~15 minutes to fall asleep.
                            """)
                    }
                    .padding(.top, 8)
                    Card {
                        ForEach(suggestions(now: now)) { suggestion in
                            SuggestionRow(suggestion: suggestion, isPassed: mode == .wakeAt && suggestion.time < now)
                        }
                    }
                }
                .screen()
                .padding(.vertical, 8)
            }
        }
        .sensoryFeedback(.selection, trigger: wakeMinutes)
        .navigationTitle("Sleep")
    }

    private func hero(now: Date) -> some View {
        Card {
            Picker("Mode", selection: $mode.animation(.snappy)) {
                ForEach(SleepMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            switch mode {
            case .wakeAt:
                let wake = SleepSuggestion.nextOccurrence(ofMinutes: wakeMinutes, after: now)
                Button {
                    withAnimation(.snappy) { editingWake.toggle() }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(wake, format: .dateTime.hour().minute())
                                .font(.clock(52))
                                .foregroundStyle(editingWake ? Color.accentColor : .primary)
                                .contentTransition(.numericText())
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.tertiary)
                                .rotationEffect(.degrees(editingWake ? 90 : 0))
                        }
                        Text(untilText(wake, now: now)).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Wake up at \(wake.formatted(.dateTime.hour().minute()))")
                .accessibilityHint(editingWake ? "Hides the time picker" : "Changes the wake time")

                if editingWake {
                    DatePicker("Wake up at", selection: $wakeMinutes.timeOfDay, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                }
            case .bedNow:
                VStack(alignment: .leading, spacing: 2) {
                    Text(now, format: .dateTime.hour().minute())
                        .font(.clock(52))
                        .contentTransition(.numericText())
                    Text("Asleep by ~\(now.addingTimeInterval(SleepSuggestion.fallAsleepTime).formatted(.dateTime.hour().minute()))")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func suggestions(now: Date) -> [SleepSuggestion] {
        switch mode {
        case .wakeAt: SleepSuggestion.bedtimes(wakingAt: SleepSuggestion.nextOccurrence(ofMinutes: wakeMinutes, after: now))
        case .bedNow: SleepSuggestion.wakeTimes(goingToBedAt: now)
        }
    }

    private func untilText(_ wake: Date, now: Date) -> String {
        let day = Calendar.current.isDateInToday(wake) ? "Today" : "Tomorrow"
        let minutes = Int(wake.timeIntervalSince(now) / 60)
        return "\(day) · in \(minutes / 60)h \(minutes % 60)m"
    }
}

private struct SuggestionRow: View {
    let suggestion: SleepSuggestion
    let isPassed: Bool

    private var isHighlighted: Bool { suggestion.isRecommended && !isPassed }

    var body: some View {
        HStack(alignment: .center, spacing: Theme.spacing) {
            Text(suggestion.time, format: .dateTime.hour().minute())
                .font(.clock(28, weight: isHighlighted ? .regular : .light))
                .strikethrough(isPassed)
                .contentTransition(.numericText())
                .frame(maxWidth: .infinity, alignment: .leading)
            CycleBar(cycles: suggestion.cycles, isHighlighted: isHighlighted)
            Text("\(suggestion.hours.formatted(.number.precision(.fractionLength(0...1))))h")
                .font(.subheadline)
                .fontWeight(isHighlighted ? .semibold : .regular)
                .monospacedDigit()
                .frame(width: 40, alignment: .trailing)
        }
        .foregroundStyle(isHighlighted ? .primary : .secondary)
        .opacity(isPassed ? 0.45 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(suggestion.time.formatted(.dateTime.hour().minute())), \(suggestion.cycles) cycles")
        .accessibilityValue(isPassed ? "Passed" : suggestion.isRecommended ? "Recommended" : "")
    }
}

/// One segment per sleep cycle, out of the maximum offered.
private struct CycleBar: View {
    let cycles: Int
    let isHighlighted: Bool

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<(SleepSuggestion.cycleCounts.max() ?? 6), id: \.self) { index in
                Capsule()
                    .fill(index < cycles ? (isHighlighted ? Color.accentColor : Color.secondary) : Theme.hairline)
                    .frame(width: 6, height: 16)
            }
        }
    }
}

#Preview {
    NavigationStack { SleepView() }
}
