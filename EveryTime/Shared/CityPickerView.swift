import SwiftUI

struct CityPickerView: View {
    let excluded: Set<String>
    let onPick: (WorldCity) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var results: [WorldCity] {
        guard !query.isEmpty else { return WorldCity.all }
        return WorldCity.all.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.timeZoneIdentifier.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List(results, id: \.self) { city in
                let added = excluded.contains(city.id)
                Button {
                    onPick(city)
                    dismiss()
                } label: {
                    HStack {
                        Text(city.name).foregroundStyle(added ? .secondary : .primary)
                        Spacer()
                        Text(city.timeZoneIdentifier).font(.caption).foregroundStyle(.secondary)
                        if added { Image(systemName: "checkmark") }
                    }
                }
                .disabled(added)
            }
            .overlay {
                if results.isEmpty { ContentUnavailableView.search(text: query) }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search city or time zone")
            .navigationTitle("Add City")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}
