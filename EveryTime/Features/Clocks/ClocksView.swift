import SwiftUI

struct ClocksView: View {
    private let zones = [
        TimeZoneEntry(label: "San Francisco", identifier: "America/Los_Angeles"),
        TimeZoneEntry(label: "New York", identifier: "America/New_York"),
        TimeZoneEntry(label: "London", identifier: "Europe/London"),
        TimeZoneEntry(label: "Singapore", identifier: "Asia/Singapore"),
        TimeZoneEntry(label: "Sydney", identifier: "Australia/Sydney"),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section("World Clock") {
                    ForEach(zones) { zone in
                        NavigationLink(zone.label) {
                            Text(zone.identifier)
                        }
                    }
                }
                Section {
                    NavigationLink("Global meeting time lookup") {
                        MeetingLookupView()
                    }
                }
            }
            .navigationTitle("Clocks")
        }
    }
}

struct MeetingLookupView: View {
    var body: some View {
        Text("Find overlapping meeting hours across time zones")
            .foregroundStyle(.secondary)
            .navigationTitle("Meeting Lookup")
    }
}

#Preview {
    ClocksView()
}
