import Foundation

struct WaitEntry: Identifiable {
    let id = UUID()
    let place: String
    let detail: String
    let placeholderMinutes: Int
}
