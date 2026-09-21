import Foundation

struct MeetingTimeZone: Identifiable {
    let id = UUID()
    let city: String
    let timeZoneIdentifier: String
}
