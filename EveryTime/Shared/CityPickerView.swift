import SwiftUI

struct CityPickerView: View {
    let excluded: Set<String>
    let onPick: (WorldCity) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var zones: [WorldCity] { TimeZoneQuery.matches(query) }

    private var cities: [WorldCity] {
        guard !query.isEmpty else { return WorldCity.all }
        return WorldCity.all.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.timeZoneIdentifier.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            let zones = zones, cities = cities
            List {
                if !zones.isEmpty {
                    Section("Time zones") { ForEach(zones, id: \.self, content: row) }
                    if !cities.isEmpty { Section("Cities") { ForEach(cities, id: \.self, content: row) } }
                } else {
                    ForEach(cities, id: \.self, content: row)
                }
            }
            .overlay {
                if zones.isEmpty && cities.isEmpty { ContentUnavailableView.search(text: query) }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "City, PST, UTC+8 or Asia/Tokyo")
            .navigationTitle("Add City or Zone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private func row(_ city: WorldCity) -> some View {
        let added = excluded.contains(city.id)
        return Button {
            onPick(city)
            dismiss()
        } label: {
            HStack {
                Text(city.name).foregroundStyle(added ? .secondary : .primary)
                Spacer()
                Text(Self.detail(city)).font(.caption).foregroundStyle(.secondary)
                if added { Image(systemName: "checkmark") }
            }
        }
        .disabled(added)
    }

    /// Fixed zones say so, since they won't follow daylight saving.
    static func detail(_ city: WorldCity) -> String {
        guard TimeZoneQuery.isFixed(city) else { return city.timeZoneIdentifier }
        return TimeZoneQuery.label(minutes: city.timeZone.secondsFromGMT() / 60) + " · no DST"
    }
}
