import SwiftUI

struct MeetingsView: View {
    private let participants = [
        MeetingTimeZone(city: "San Francisco", timeZoneIdentifier: "America/Los_Angeles"),
        MeetingTimeZone(city: "London", timeZoneIdentifier: "Europe/London"),
        MeetingTimeZone(city: "Singapore", timeZoneIdentifier: "Asia/Singapore"),
    ]

    private let overlapHours = ["9", "10", "11", "12", "13", "14", "15", "16"]

    var body: some View {
        NavigationStack {
            List {
                Section("Time Zones") {
                    ForEach(participants) { participant in
                        Text(participant.city)
                    }
                    NavigationLink("Add Time Zone") {
                        Text("Search and add a time zone to compare")
                            .foregroundStyle(.secondary)
                            .navigationTitle("Add Time Zone")
                    }
                }
                Section("Overlap") {
                    ForEach(participants) { participant in
                        HStack {
                            Text(participant.city)
                            Spacer()
                            ForEach(overlapHours, id: \.self) { hour in
                                Text(hour)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 18)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Meetings")
        }
    }
}

#Preview {
    MeetingsView()
}
