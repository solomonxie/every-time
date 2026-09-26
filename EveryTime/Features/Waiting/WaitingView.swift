import SwiftUI

struct WaitingView: View {
    private let entries = [
        WaitEntry(place: "DMV", detail: "Downtown Office", placeholderMinutes: 42),
        WaitEntry(place: "Space Mountain", detail: "Disneyland", placeholderMinutes: 35),
        WaitEntry(place: "Hagrid's", detail: "Universal Studios", placeholderMinutes: 70),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacing) {
                SectionLabel(title: "Now") {
                    Text("Sample data")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.Tone.edge, in: Capsule())
                        .foregroundStyle(Theme.Tone.warn)
                }
                ForEach(entries) { WaitRow(entry: $0) }
                Label("Sample data — live wait times coming later.", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
            }
            .screen()
            .padding(.vertical, 8)
        }
        .navigationTitle("Wait times")
    }
}

private struct WaitRow: View {
    let entry: WaitEntry

    var body: some View {
        Card {
            HStack(alignment: .center, spacing: Theme.spacing) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.place).font(.cardTitle)
                    Text(entry.detail).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(entry.placeholderMinutes)").font(.clock(40))
                    Text("min").font(.label).foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack { WaitingView() }
}
