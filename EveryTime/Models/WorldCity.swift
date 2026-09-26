import Foundation

struct WorldCity: Codable, Identifiable, Hashable {
    var id: String { timeZoneIdentifier }
    let name: String
    let timeZoneIdentifier: String

    var timeZone: TimeZone { TimeZone(identifier: timeZoneIdentifier) ?? .current }

    init(timeZoneIdentifier: String) {
        self.timeZoneIdentifier = timeZoneIdentifier
        name = timeZoneIdentifier.split(separator: "/").last
            .map { $0.replacingOccurrences(of: "_", with: " ") } ?? timeZoneIdentifier
    }

    static var local: WorldCity { WorldCity(timeZoneIdentifier: TimeZone.current.identifier) }

    static let all: [WorldCity] = TimeZone.knownTimeZoneIdentifiers
        .filter { $0.contains("/") && !$0.hasPrefix("Etc/") }
        .map(WorldCity.init)
        .sorted { $0.name < $1.name }

    /// "+8h", "−3h 30m", "" when equal to the device zone.
    func offsetLabel(at date: Date = .now) -> String {
        let diff = timeZone.secondsFromGMT(for: date) - TimeZone.current.secondsFromGMT(for: date)
        guard diff != 0 else { return "" }
        let sign = diff > 0 ? "+" : "−"
        let h = abs(diff) / 3600, m = abs(diff) % 3600 / 60
        return m == 0 ? "\(sign)\(h)h" : "\(sign)\(h)h \(m)m"
    }
}
