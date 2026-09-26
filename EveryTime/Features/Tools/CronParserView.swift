import SwiftUI

struct CronParserView: View {
    @State private var text = "*/15 9-17 * * 1-5"

    private static let examples = ["@hourly", "0 0 * * *", "30 8 * * 1", "*/15 9-17 * * 1-5", "0 0 1 */3 *"]

    var body: some View {
        Form {
            Section {
                TextField("Cron expression", text: $text)
                    .font(.body.monospaced())
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } footer: {
                Text("minute hour day-of-month month day-of-week")
            }

            switch Result(catching: { try CronExpression(text) }) {
            case .success(let cron):
                Section {
                    Text(cron.summary)
                        .font(.headline)
                }
                Section("Next runs") {
                    TimelineView(.everyMinute) { context in
                        let runs = cron.nextRuns(after: context.date)
                        if runs.isEmpty {
                            Text("No upcoming runs").foregroundStyle(.secondary)
                        } else {
                            ForEach(runs, id: \.self) { run in
                                Text(run, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            case .failure(let error):
                Section {
                    Label(error.localizedDescription, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }

            Section("Examples") {
                ForEach(Self.examples, id: \.self) { example in
                    Button {
                        text = example
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(example).font(.body.monospaced())
                            if let cron = try? CronExpression(example) {
                                Text(cron.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Cron parser")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { CronParserView() }
}
