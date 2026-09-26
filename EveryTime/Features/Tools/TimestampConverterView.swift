import SwiftUI

struct TimestampConverterView: View {
    @State private var input = String(Int(Date().timeIntervalSince1970))
    @State private var date = Date()

    var body: some View {
        Form {
            Section("Timestamp → Date") {
                TextField("Unix timestamp", text: $input)
                    .keyboardType(.numbersAndPunctuation)
                    .autocorrectionDisabled()
                    .font(.body.monospacedDigit())
                result
            }
            Section("Date → Timestamp") {
                DatePicker("Date", selection: $date)
                CopyableRow(title: "Seconds", value: String(Int(date.timeIntervalSince1970)))
            }
        }
        .navigationTitle("Timestamp converter")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var result: some View {
        switch ParsedTimestamp(input) {
        case .empty:
            EmptyView()
        case .invalid:
            Label("Not a number", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        case let .valid(parsed, isMilliseconds):
            LabeledContent("Local", value: parsed.formatted(Self.style(timeZone: .current)))
            LabeledContent("UTC", value: parsed.formatted(Self.style(timeZone: .gmt)))
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                LabeledContent("Relative", value: parsed.formatted(.relative(presentation: .named)))
            }
            Text(isMilliseconds ? "Read as milliseconds" : "Read as seconds")
                .font(.footnote)
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
