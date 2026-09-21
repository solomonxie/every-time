import SwiftUI

struct MoreView: View {
    private let rows = [
        "Movement / stand-up reminders",
        "Waiting / queue time lookup (public data)",
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(rows, id: \.self) { row in
                        NavigationLink(row) {
                            Text(row)
                                .foregroundStyle(.secondary)
                                .navigationTitle(row)
                        }
                    }
                }
                Section {
                    NavigationLink("About") {
                        Text("Every Time")
                            .navigationTitle("About")
                    }
                }
            }
            .navigationTitle("More")
        }
    }
}

#Preview {
    MoreView()
}
