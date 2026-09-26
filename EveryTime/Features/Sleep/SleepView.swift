import SwiftUI

struct SleepView: View {
    @State private var mode: SleepMode = .wakeAt
    @State private var wakeTime = Calendar.current.date(bySettingHour: 6, minute: 30, second: 0, of: .now) ?? .now
    @State private var showsInfo = false

    var body: some View {
        NavigationStack {
            TimelineView(.everyMinute) { context in
                List {
                    Section {
                        Picker("Mode", selection: $mode) {
                            ForEach(SleepMode.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }

                    if mode == .wakeAt {
                        Section {
                            DatePicker("Wake up at", selection: $wakeTime, displayedComponents: .hourAndMinute)
                        }
                    }

                    Section {
                        ForEach(suggestions(now: context.date)) { SuggestionRow(suggestion: $0) }
                    } header: {
                        header
                    }
                }
            }
            .navigationTitle("Sleep")
        }
    }

    private func suggestions(now: Date) -> [SleepSuggestion] {
        switch mode {
        case .wakeAt: SleepSuggestion.bedtimes(wakingAt: wakeTime)
        case .bedNow: SleepSuggestion.wakeTimes(goingToBedAt: now)
        }
    }

    private var header: some View {
        HStack(spacing: 4) {
            Text(mode == .wakeAt ? "Go to bed at" : "Wake up at")
            Button {
                showsInfo = true
            } label: {
                Image(systemName: "info.circle")
            }
            .accessibilityLabel("About sleep cycles")
            .popover(isPresented: $showsInfo) {
                Text("A sleep cycle is about 90 minutes. Waking between cycles feels easier. Includes ~15 minutes to fall asleep.")
                    .font(.callout)
                    .padding()
                    .frame(idealWidth: 280)
                    .fixedSize(horizontal: false, vertical: true)
                    .presentationCompactAdaptation(.popover)
            }
        }
    }
}

private struct SuggestionRow: View {
    let suggestion: SleepSuggestion

    var body: some View {
        HStack {
            Text(suggestion.time, format: .dateTime.hour().minute())
                .font(suggestion.isRecommended ? .title3.bold() : .body)
            Spacer()
            Text("\(suggestion.cycles) cycles · \(suggestion.hours.formatted(.number.precision(.fractionLength(0...1))))h")
                .foregroundStyle(suggestion.isRecommended ? .primary : .secondary)
                .fontWeight(suggestion.isRecommended ? .semibold : .regular)
        }
        .monospacedDigit()
        .accessibilityElement(children: .combine)
        .accessibilityHint(suggestion.isRecommended ? "Recommended" : "")
    }
}

#Preview {
    SleepView()
}
