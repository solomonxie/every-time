import SwiftUI

struct ToolsView: View {
    private let rows = [
        "Unix timestamp",
        "Timestamp converter",
        "Cron expression parser",
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
            .navigationTitle("Tools")
        }
    }
}

#Preview {
    ToolsView()
}
