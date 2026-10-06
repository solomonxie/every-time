import SwiftUI

struct CityPickerView: View {
    let excluded: Set<String>
    let onPick: (WorldCity) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var searching = false

    private var zones: [WorldCity] { TimeZoneQuery.matches(query) }

    private var cities: [WorldCity] {
        guard !query.isEmpty else { return WorldCity.all }
        let countryKeys = WorldCity.keys(inCountryMatching: query)
        return WorldCity.all.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || countryKeys.contains($0.timeZoneIdentifier) || countryKeys.contains($0.name)
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
            .searchable(text: $query, isPresented: $searching, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "City, country, PST, UTC+8 or Asia/Tokyo")
            .task { searching = true }
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
                VStack(alignment: .leading, spacing: 2) {
                    Text(city.name).foregroundStyle(added ? .secondary : .primary)
                    if let country = city.country { Text(country).font(.caption).foregroundStyle(.secondary) }
                }
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
