import Foundation

/// What the widget shows, published by the phone app.
struct Glance: Codable, Equatable {
    struct Countdown: Codable, Equatable, Identifiable {
        let id: UUID
        let name: String
        let target: Date
    }

    var cities: [WorldCity] = []
    var countdowns: [Countdown] = []

    static let appGroup = AppIdentifier.appGroup
    static let key = "glance"

    static var shared: UserDefaults { UserDefaults(suiteName: appGroup) ?? .standard }

    static func load(from defaults: UserDefaults = shared) -> Glance {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(Glance.self, from: $0) } ?? Glance()
    }

    func save(to defaults: UserDefaults = shared) {
        defaults.set(try? JSONEncoder().encode(self), forKey: Self.key)
    }

    func upcoming(after now: Date) -> [Countdown] {
        countdowns.filter { $0.target > now }.sorted { $0.target < $1.target }
    }
}
