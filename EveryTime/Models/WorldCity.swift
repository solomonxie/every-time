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

    init(name: String, timeZoneIdentifier: String) {
        self.name = name
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    static var local: WorldCity { WorldCity(timeZoneIdentifier: TimeZone.current.identifier) }

    /// Zone cities plus major cities that share another city's zone (Beijing → Asia/Shanghai).
    static let all: [WorldCity] = {
        let zones = TimeZone.knownTimeZoneIdentifiers
            .filter { $0.contains("/") && !$0.hasPrefix("Etc/") }
            .map(WorldCity.init)
        let names = Set(zones.map(\.name))
        let extra = aliases
            .filter { !names.contains($0.key) && TimeZone(identifier: $0.value) != nil }
            .map { WorldCity(name: $0.key, timeZoneIdentifier: $0.value) }
        return (zones + extra).sorted { $0.name < $1.name }
    }()

    private static let aliases: [String: String] = [
        "Beijing": "Asia/Shanghai", "Shenzhen": "Asia/Shanghai", "Guangzhou": "Asia/Shanghai",
        "Chengdu": "Asia/Shanghai", "Hangzhou": "Asia/Shanghai", "Wuhan": "Asia/Shanghai", "Xi'an": "Asia/Shanghai",
        "Osaka": "Asia/Tokyo", "Kyoto": "Asia/Tokyo", "Busan": "Asia/Seoul",
        "Mumbai": "Asia/Kolkata", "Delhi": "Asia/Kolkata", "New Delhi": "Asia/Kolkata",
        "Bangalore": "Asia/Kolkata", "Chennai": "Asia/Kolkata", "Hyderabad": "Asia/Kolkata",
        "Hanoi": "Asia/Bangkok", "Abu Dhabi": "Asia/Dubai", "Tel Aviv": "Asia/Jerusalem",
        "Canberra": "Australia/Sydney",
        "Frankfurt": "Europe/Berlin", "Munich": "Europe/Berlin", "Hamburg": "Europe/Berlin",
        "Barcelona": "Europe/Madrid", "Milan": "Europe/Rome", "Geneva": "Europe/Zurich",
        "Manchester": "Europe/London", "Edinburgh": "Europe/London", "St Petersburg": "Europe/Moscow",
        "San Francisco": "America/Los_Angeles", "Seattle": "America/Los_Angeles",
        "San Diego": "America/Los_Angeles", "Las Vegas": "America/Los_Angeles",
        "Washington DC": "America/New_York", "Boston": "America/New_York", "Miami": "America/New_York",
        "Atlanta": "America/New_York", "Philadelphia": "America/New_York",
        "Dallas": "America/Chicago", "Houston": "America/Chicago", "Austin": "America/Chicago",
        "Salt Lake City": "America/Denver", "Montreal": "America/Toronto", "Ottawa": "America/Toronto",
        "Rio de Janeiro": "America/Sao_Paulo", "Brasília": "America/Sao_Paulo",
    ]

    /// "+8h", "−3h 30m", "" when equal to the device zone.
    func offsetLabel(at date: Date = .now) -> String {
        let diff = timeZone.secondsFromGMT(for: date) - TimeZone.current.secondsFromGMT(for: date)
        guard diff != 0 else { return "" }
        let sign = diff > 0 ? "+" : "−"
        let h = abs(diff) / 3600, m = abs(diff) % 3600 / 60
        return m == 0 ? "\(sign)\(h)h" : "\(sign)\(h)h \(m)m"
    }
}
