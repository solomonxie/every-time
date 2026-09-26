import SwiftUI

struct UnixTimestampView: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let date = context.date
            let seconds = String(Int(date.timeIntervalSince1970))
            List {
                Section {
                    CopyButton(value: { String(Int(Date().timeIntervalSince1970)) }) {
                        Text(seconds)
                            .font(.system(size: 44, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                    }
                    .listRowBackground(Color.clear)
                }
                Section {
                    CopyableRow(title: "Seconds", value: seconds)
                    CopyableRow(title: "Milliseconds", value: String(Int64(date.timeIntervalSince1970 * 1000)))
                    CopyableRow(title: "ISO 8601", value: date.formatted(.iso8601))
                }
            }
        }
        .navigationTitle("Unix timestamp")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { UnixTimestampView() }
}
