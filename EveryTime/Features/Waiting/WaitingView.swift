import SwiftUI

struct WaitingView: View {
    private let entries = [
        WaitEntry(place: "DMV — Downtown Office", placeholderWait: "42 min"),
        WaitEntry(place: "Disneyland — Space Mountain", placeholderWait: "35 min"),
        WaitEntry(place: "Universal Studios — Hagrid's", placeholderWait: "70 min"),
    ]

    var body: some View {
        List {
            Section {
                ForEach(entries) { entry in
                    LabeledContent(entry.place, value: entry.placeholderWait)
                }
            } footer: {
                Text("Sample data — live wait times coming later.")
            }
        }
        .navigationTitle("Wait times")
    }
}

#Preview {
    NavigationStack { WaitingView() }
}
