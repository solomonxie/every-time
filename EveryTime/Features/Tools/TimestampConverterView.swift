import SwiftUI

struct TimestampConverterView: View {
    @State private var input = String(Int(Date().timeIntervalSince1970))
    @State private var date = Date()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacing) {
                SectionLabel("Timestamp → Date")
                Card {
                    HStack(spacing: 8) {
                        TextField("Unix timestamp", text: $input, prompt: Text("1758790867"))
                            .font(.system(.title2, design: .monospaced))
                            .keyboardType(.numbersAndPunctuation)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                        Button("Now") { input = String(Int(Date().timeIntervalSince1970)) }
                            .buttonStyle(.soft)
                    }
                    status
                }
                if case let .valid(parsed, _) = ParsedTimestamp(input) {
                    Card {
                        CopyableRow(title: "Local", value: parsed.formatted(Self.style(timeZone: .current)))
                        CopyableRow(title: "UTC", value: parsed.formatted(Self.style(timeZone: .gmt)))
                        TimelineView(.periodic(from: .now, by: 1)) { _ in
                            CopyableRow(title: "Relative", value: parsed.formatted(.relative(presentation: .named)))
                        }
                    }
                    .transition(.opacity)
                }

                SectionLabel("Date → Timestamp")
                    .padding(.top, 20)
                Card {
                    DatePicker("Date", selection: $date)
                        .font(.system(.body, design: .rounded))
                    CopyableRow(title: "Seconds", value: String(Int(date.timeIntervalSince1970)))
                    CopyableRow(title: "Milliseconds", value: String(Int64(date.timeIntervalSince1970 * 1000)))
                }
            }
            .screen()
            .padding(.vertical, Theme.spacing)
            .animation(.snappy, value: ParsedTimestamp(input))
        }
        .scrollDismissesKeyboard(.interactively)
        .copyToast()
        .navigationTitle("Timestamp converter")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var status: some View {
        switch ParsedTimestamp(input) {
        case .empty:
            Text("Seconds or milliseconds")
                .font(.label)
                .foregroundStyle(.secondary)
        case .invalid:
            Label("Not a number", systemImage: "exclamationmark.triangle.fill")
                .font(.label)
                .foregroundStyle(Theme.Tone.warn)
        case let .valid(_, isMilliseconds):
            Text(isMilliseconds ? "Read as milliseconds" : "Read as seconds")
                .font(.label)
                .foregroundStyle(.secondary)
        }
    }

    private static func style(timeZone: TimeZone) -> Date.FormatStyle {
        var style = Date.FormatStyle.dateTime.weekday(.abbreviated).month(.abbreviated).day().year().hour().minute().second()
        style.timeZone = timeZone
        return style
    }
}

enum ParsedTimestamp: Equatable {
    case empty
    case invalid
    case valid(Date, isMilliseconds: Bool)

    static let millisecondsThreshold = 1e11

    init(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { self = .empty; return }
        guard let value = Double(trimmed), value.isFinite else { self = .invalid; return }
        let isMilliseconds = abs(value) > Self.millisecondsThreshold
        self = .valid(Date(timeIntervalSince1970: isMilliseconds ? value / 1000 : value), isMilliseconds: isMilliseconds)
    }
}

#Preview {
    NavigationStack { TimestampConverterView() }
}
