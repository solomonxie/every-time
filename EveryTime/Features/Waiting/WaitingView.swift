import SwiftUI

struct WaitingView: View {
    private let entries = [
        WaitEntry(place: "DMV — Downtown Office", placeholderWait: "42 min"),
        WaitEntry(place: "Disneyland — Space Mountain", placeholderWait: "35 min"),
        WaitEntry(place: "Universal Studios — Hagrid's", placeholderWait: "70 min"),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(entries) { entry in
                        HStack {
                            Text(entry.place)
                            Spacer()
                            Text(entry.placeholderWait)
                                .foregroundStyle(.secondary)
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
            .navigationTitle("Waiting")
        }
    }
}

#Preview {
    WaitingView()
}
