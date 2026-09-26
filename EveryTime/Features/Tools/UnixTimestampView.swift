import SwiftUI

struct UnixTimestampView: View {
    var body: some View {
        ScrollView {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let date = context.date
                let seconds = String(Int(date.timeIntervalSince1970))
                VStack(spacing: 24) {
                    CopyButton(value: { String(Int(Date().timeIntervalSince1970)) }) {
                        VStack(spacing: 8) {
                            Text(seconds)
                                .font(.clock(64, weight: .thin))
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .contentTransition(.numericText())
                                .animation(.snappy, value: seconds)
                            Text("Seconds since 1970 · tap to copy")
                                .font(.label)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .contentShape(Rectangle())
                    }
                    Card {
                        CopyableRow(title: "Seconds", value: seconds)
                        CopyableRow(title: "Milliseconds", value: String(Int64(date.timeIntervalSince1970 * 1000)))
                        CopyableRow(title: "ISO 8601", value: date.formatted(.iso8601))
                    }
                }
                .screen()
            }
        }
        .copyToast()
        .navigationTitle("Unix timestamp")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { UnixTimestampView() }
}
