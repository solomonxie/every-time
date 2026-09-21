import SwiftUI

struct ClocksView: View {
    private let clocks = [
        WorldClock(city: "San Francisco", timeZoneIdentifier: "America/Los_Angeles", placeholderTime: "9:41 AM"),
        WorldClock(city: "New York", timeZoneIdentifier: "America/New_York", placeholderTime: "12:41 PM"),
        WorldClock(city: "London", timeZoneIdentifier: "Europe/London", placeholderTime: "5:41 PM"),
        WorldClock(city: "Singapore", timeZoneIdentifier: "Asia/Singapore", placeholderTime: "1:41 AM"),
        WorldClock(city: "Sydney", timeZoneIdentifier: "Australia/Sydney", placeholderTime: "3:41 AM"),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section("World Clock") {
                    ForEach(clocks) { clock in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(clock.city)
                                Text(clock.timeZoneIdentifier)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(clock.placeholderTime)
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                }
                Section {
                    NavigationLink("Add City") {
                        AddCityView()
                    }
                }
            }
            .navigationTitle("Clocks")
        }
    }
}

struct AddCityView: View {
    var body: some View {
        Text("Search and add a city to your world clock")
            .foregroundStyle(.secondary)
            .navigationTitle("Add City")
    }
}

#Preview {
    ClocksView()
}
