import SwiftUI

struct SleepView: View {
    private let rows = [
        "Ideal wake-up time calculator",
        "Sleep-time alarm (REM-cycle based)",
        "Timeshifter-style jet lag adjustment",
    ]

    var body: some View {
        NavigationStack {
            List(rows, id: \.self) { row in
                NavigationLink(row) {
                    Text(row)
                        .foregroundStyle(.secondary)
                        .navigationTitle(row)
                }
            }
            .navigationTitle("Sleep")
        }
    }
}

#Preview {
    SleepView()
}
