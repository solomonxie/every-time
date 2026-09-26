import SwiftUI

struct CronParserView: View {
    @State private var text = "*/15 9-17 * * 1-5"

    private static let examples = ["@hourly", "0 0 * * *", "30 8 * * 1", "*/15 9-17 * * 1-5", "0 0 1 */3 *"]

    var body: some View {
        let parsed = Result { try CronExpression(text) }
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacing) {
                Card {
                    TextField("Cron expression", text: $text)
                        .font(.system(.title3, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.done)
                    if case .failure(let error) = parsed {
                        Label(error.localizedDescription, systemImage: "exclamationmark.triangle.fill")
                            .font(.label)
                            .foregroundStyle(Theme.Tone.warn)
                    } else {
                        Text("minute  hour  day  month  weekday")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }

                if case .success(let cron) = parsed {
                    Text(cron.summary)
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                    SectionLabel("Next runs")
                    Card {
                        TimelineView(.everyMinute) { context in
                            nextRuns(cron.nextRuns(after: context.date))
                        }
                    }
                }

                SectionLabel("Examples")
                    .padding(.top, 12)
                examples
            }
            .screen()
            .padding(.vertical, Theme.spacing)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Cron parser")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func nextRuns(_ runs: [Date]) -> some View {
        if runs.isEmpty {
            Text("No upcoming runs").foregroundStyle(.secondary)
        } else {
            ForEach(runs, id: \.self) { run in
                HStack {
                    Text(run, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                    Spacer()
                    Text(run, format: .dateTime.hour().minute())
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .font(.system(.body, design: .rounded))
            }
        }
    }

    private var examples: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Self.examples, id: \.self) { example in
                    Button { text = example } label: {
                        Text(example).font(.system(.subheadline, design: .monospaced, weight: .medium))
                    }
                    .buttonStyle(.soft)
                    .foregroundStyle(example == text ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                }
            }
        }
        .contentMargins(.horizontal, Theme.padding, for: .scrollContent)
        .padding(.horizontal, -Theme.padding)
        .sensoryFeedback(.selection, trigger: text) { _, new in Self.examples.contains(new) }
    }
}

#Preview {
    NavigationStack { CronParserView() }
}
