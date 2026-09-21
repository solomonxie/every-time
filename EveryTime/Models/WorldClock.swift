import Foundation

struct WorldClock: Identifiable {
    let id = UUID()
    let city: String
    let timeZoneIdentifier: String
    let placeholderTime: String
}
