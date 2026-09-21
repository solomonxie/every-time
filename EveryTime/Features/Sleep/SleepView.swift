import SwiftUI

struct SleepView: View {
    @State private var wakeTime = Date()

    // TODO: replace with real ~90-minute REM sleep cycle math (count backward
    // from wakeTime in 90-minute increments plus ~15 min to fall asleep)
    private let suggestions = [
        SleepSuggestion(bedtime: "9:15 PM", cycles: 6),
        SleepSuggestion(bedtime: "10:45 PM", cycles: 5),
        SleepSuggestion(bedtime: "12:15 AM", cycles: 4),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section("Wake Up At") {
                    DatePicker("Desired wake time", selection: $wakeTime, displayedComponents: .hourAndMinute)
                }
                Section("Suggested Bedtimes") {
                    ForEach(suggestions) { suggestion in
                        HStack {
                            Text(suggestion.bedtime)
                            Spacer()
                            Text("\(suggestion.cycles) cycles")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Sleep")
        }
    }
}

#Preview {
    SleepView()
}
