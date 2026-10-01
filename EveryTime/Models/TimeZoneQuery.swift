import Foundation

/// Time zones typed by name: abbreviations (PST, CET), offsets (UTC+8, GMT-5:30) and IANA ids (Asia/Shanghai).
enum TimeZoneQuery {
    struct Abbreviation {
        let code: String
        /// Minutes from UTC while this abbreviation is in effect.
        let minutes: Int
        let zone: String
        let name: String
        /// The zone's DST-following name, e.g. "Pacific Time".
        let generic: String
    }

    /// Zones matching the text, best first; empty when it reads as neither a zone nor an abbreviation.
    static func matches(_ text: String) -> [WorldCity] {
        let query = text.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return [] }
        var out: [WorldCity] = []
        if let fixed = offset(query) { out.append(fixed) }
        if let zone = identifier(query) { out.append(zone) }
        out += abbreviations(query)
        var seen = Set<String>()
        return out.filter { seen.insert("\($0.name)|\($0.id)").inserted }
    }

    // MARK: Offsets

    private static var offsetPattern: Regex<(Substring, Substring?, Substring?, Substring?, Substring?)> {
        #/(utc|gmt)?\s*(?:([+\-−–])\s*(\d{1,2})(?:[:.h]?(\d{2}))?)?/#.ignoresCase()
    }

    /// "UTC+8", "gmt-5", "+05:30", "UTC" → a fixed-offset zone named the way it was typed.
    static func offset(_ text: String) -> WorldCity? {
        guard let match = text.trimmingCharacters(in: .whitespaces).wholeMatch(of: offsetPattern) else { return nil }
        let prefix = match.1.map { $0.uppercased() == "GMT" ? "GMT" : "UTC" } ?? "UTC"
        guard let sign = match.2, let hourText = match.3 else {
            return match.1 == nil ? nil : WorldCity(name: prefix, timeZoneIdentifier: "GMT")
        }
        guard let hours = Int(hourText), let mins = Int(match.4 ?? "0"), mins < 60 else { return nil }
        let negative = sign != "+"
        let total = (hours * 60 + mins) * (negative ? -1 : 1)
        guard (-12 * 60)...(14 * 60) ~= total else { return nil }
        return fixed(minutes: total, prefix: prefix)
    }

    /// Zone with no daylight saving; "GMT+0800" style ids, which TimeZone accepts back.
    static func fixed(minutes: Int, prefix: String = "UTC", name: String? = nil) -> WorldCity? {
        guard let zone = TimeZone(secondsFromGMT: minutes * 60) else { return nil }
        return WorldCity(name: name ?? label(minutes: minutes, prefix: prefix), timeZoneIdentifier: zone.identifier)
    }

    /// "UTC+8", "UTC−3:30", "UTC".
    static func label(minutes: Int, prefix: String = "UTC") -> String {
        guard minutes != 0 else { return prefix }
        let h = abs(minutes) / 60, m = abs(minutes) % 60
        return "\(prefix)\(minutes > 0 ? "+" : "−")\(h)" + (m == 0 ? "" : String(format: ":%02d", m))
    }

    static func isFixed(_ city: WorldCity) -> Bool {
        city.timeZoneIdentifier.hasPrefix("GMT") || city.timeZoneIdentifier.hasPrefix("Etc/")
    }

    // MARK: IANA ids

    /// Exact id, any case: "asia/shanghai", "Etc/GMT+8", "EST5EDT".
    static func identifier(_ text: String) -> WorldCity? {
        let known = TimeZone.knownTimeZoneIdentifiers.first { $0.caseInsensitiveCompare(text) == .orderedSame }
        let typed = text.contains("/") ? TimeZone(identifier: text) ?? TimeZone(identifier: capitalized(text)) : nil
        guard let id = known ?? typed?.identifier,
              let zone = TimeZone(identifier: id) else { return nil }
        // Etc/GMT+8 is UTC−8 (POSIX sign), so name these by their real offset.
        if id.hasPrefix("Etc/") || !id.contains("/") {
            return WorldCity(name: label(minutes: zone.secondsFromGMT() / 60), timeZoneIdentifier: id)
        }
        return WorldCity(timeZoneIdentifier: id)
    }

    /// "america/new_york" → "America/New_York", for aliases not in the known list (Asia/Kolkata).
    private static func capitalized(_ id: String) -> String {
        id.split(separator: "/", omittingEmptySubsequences: false).map { part in
            part.split(separator: "_", omittingEmptySubsequences: false).map(\.capitalized).joined(separator: "_")
        }.joined(separator: "/")
    }

    // MARK: Abbreviations

    /// "PST" → Pacific Time (follows DST) and PST itself (always UTC−8). Also matches names: "pacific", "central european".
    static func abbreviations(_ text: String) -> [WorldCity] {
        let code = text.uppercased()
        var out: [WorldCity] = []
        if let zone = genericCodes[code], let entry = table.first(where: { $0.zone == zone }) {
            out.append(WorldCity(name: entry.generic, timeZoneIdentifier: zone))
        }
        let exact = table.filter { $0.code == code }
        let named = exact.isEmpty && out.isEmpty && text.count >= 3
            ? table.filter { startsWord($0.name, text) || startsWord($0.generic, text) }
            : []
        for entry in exact + named {
            out.append(WorldCity(name: entry.generic, timeZoneIdentifier: entry.zone))
            if let fixed = fixed(minutes: entry.minutes, name: entry.code) { out.append(fixed) }
        }
        return out
    }

    /// "central eu" matches "Central European Time"; "est" doesn't match "Western".
    private static func startsWord(_ name: String, _ text: String) -> Bool {
        let name = name.lowercased(), text = text.lowercased()
        return name.hasPrefix(text) || name.contains(" " + text)
    }

    /// Short names for a zone in general, whatever the season.
    private static let genericCodes = [
        "PT": "America/Los_Angeles", "MT": "America/Denver", "CT": "America/Chicago", "ET": "America/New_York",
        "AKT": "America/Anchorage", "AT": "America/Halifax",
    ]

    static let table: [Abbreviation] = [
        .init(code: "PST", minutes: -480, zone: "America/Los_Angeles", name: "Pacific Standard Time", generic: "Pacific Time"),
        .init(code: "PDT", minutes: -420, zone: "America/Los_Angeles", name: "Pacific Daylight Time", generic: "Pacific Time"),
        .init(code: "MST", minutes: -420, zone: "America/Denver", name: "Mountain Standard Time", generic: "Mountain Time"),
        .init(code: "MDT", minutes: -360, zone: "America/Denver", name: "Mountain Daylight Time", generic: "Mountain Time"),
        .init(code: "CST", minutes: -360, zone: "America/Chicago", name: "Central Standard Time", generic: "Central Time"),
        .init(code: "CDT", minutes: -300, zone: "America/Chicago", name: "Central Daylight Time", generic: "Central Time"),
        .init(code: "EST", minutes: -300, zone: "America/New_York", name: "Eastern Standard Time", generic: "Eastern Time"),
        .init(code: "EDT", minutes: -240, zone: "America/New_York", name: "Eastern Daylight Time", generic: "Eastern Time"),
        .init(code: "AKST", minutes: -540, zone: "America/Anchorage", name: "Alaska Standard Time", generic: "Alaska Time"),
        .init(code: "AKDT", minutes: -480, zone: "America/Anchorage", name: "Alaska Daylight Time", generic: "Alaska Time"),
        .init(code: "HST", minutes: -600, zone: "Pacific/Honolulu", name: "Hawaii Standard Time", generic: "Hawaii Time"),
        .init(code: "AST", minutes: -240, zone: "America/Halifax", name: "Atlantic Standard Time", generic: "Atlantic Time"),
        .init(code: "ADT", minutes: -180, zone: "America/Halifax", name: "Atlantic Daylight Time", generic: "Atlantic Time"),
        .init(code: "NST", minutes: -210, zone: "America/St_Johns", name: "Newfoundland Standard Time", generic: "Newfoundland Time"),
        .init(code: "NDT", minutes: -150, zone: "America/St_Johns", name: "Newfoundland Daylight Time", generic: "Newfoundland Time"),
        .init(code: "BRT", minutes: -180, zone: "America/Sao_Paulo", name: "Brasília Time", generic: "Brasília Time"),
        .init(code: "ART", minutes: -180, zone: "America/Argentina/Buenos_Aires", name: "Argentina Time", generic: "Argentina Time"),
        .init(code: "WET", minutes: 0, zone: "Europe/Lisbon", name: "Western European Time", generic: "Western European Time"),
        .init(code: "WEST", minutes: 60, zone: "Europe/Lisbon", name: "Western European Summer Time", generic: "Western European Time"),
        .init(code: "BST", minutes: 60, zone: "Europe/London", name: "British Summer Time", generic: "UK Time"),
        .init(code: "CET", minutes: 60, zone: "Europe/Paris", name: "Central European Time", generic: "Central European Time"),
        .init(code: "CEST", minutes: 120, zone: "Europe/Paris", name: "Central European Summer Time", generic: "Central European Time"),
        .init(code: "EET", minutes: 120, zone: "Europe/Athens", name: "Eastern European Time", generic: "Eastern European Time"),
        .init(code: "EEST", minutes: 180, zone: "Europe/Athens", name: "Eastern European Summer Time", generic: "Eastern European Time"),
        .init(code: "MSK", minutes: 180, zone: "Europe/Moscow", name: "Moscow Time", generic: "Moscow Time"),
        .init(code: "WAT", minutes: 60, zone: "Africa/Lagos", name: "West Africa Time", generic: "West Africa Time"),
        .init(code: "CAT", minutes: 120, zone: "Africa/Maputo", name: "Central Africa Time", generic: "Central Africa Time"),
        .init(code: "SAST", minutes: 120, zone: "Africa/Johannesburg", name: "South Africa Standard Time", generic: "South Africa Time"),
        .init(code: "EAT", minutes: 180, zone: "Africa/Nairobi", name: "East Africa Time", generic: "East Africa Time"),
        .init(code: "IST", minutes: 330, zone: "Asia/Kolkata", name: "India Standard Time", generic: "India Time"),
        .init(code: "IST", minutes: 120, zone: "Asia/Jerusalem", name: "Israel Standard Time", generic: "Israel Time"),
        .init(code: "GST", minutes: 240, zone: "Asia/Dubai", name: "Gulf Standard Time", generic: "Gulf Time"),
        .init(code: "PKT", minutes: 300, zone: "Asia/Karachi", name: "Pakistan Standard Time", generic: "Pakistan Time"),
        .init(code: "NPT", minutes: 345, zone: "Asia/Kathmandu", name: "Nepal Time", generic: "Nepal Time"),
        .init(code: "ICT", minutes: 420, zone: "Asia/Bangkok", name: "Indochina Time", generic: "Indochina Time"),
        .init(code: "WIB", minutes: 420, zone: "Asia/Jakarta", name: "Western Indonesia Time", generic: "Western Indonesia Time"),
        .init(code: "CST", minutes: 480, zone: "Asia/Shanghai", name: "China Standard Time", generic: "China Time"),
        .init(code: "HKT", minutes: 480, zone: "Asia/Hong_Kong", name: "Hong Kong Time", generic: "Hong Kong Time"),
        .init(code: "SGT", minutes: 480, zone: "Asia/Singapore", name: "Singapore Time", generic: "Singapore Time"),
        .init(code: "PHT", minutes: 480, zone: "Asia/Manila", name: "Philippine Time", generic: "Philippine Time"),
        .init(code: "AWST", minutes: 480, zone: "Australia/Perth", name: "Australian Western Standard Time", generic: "Western Australia Time"),
        .init(code: "JST", minutes: 540, zone: "Asia/Tokyo", name: "Japan Standard Time", generic: "Japan Time"),
        .init(code: "KST", minutes: 540, zone: "Asia/Seoul", name: "Korea Standard Time", generic: "Korea Time"),
        .init(code: "ACST", minutes: 570, zone: "Australia/Adelaide", name: "Australian Central Standard Time", generic: "Central Australia Time"),
        .init(code: "ACDT", minutes: 630, zone: "Australia/Adelaide", name: "Australian Central Daylight Time", generic: "Central Australia Time"),
        .init(code: "AEST", minutes: 600, zone: "Australia/Sydney", name: "Australian Eastern Standard Time", generic: "Eastern Australia Time"),
        .init(code: "AEDT", minutes: 660, zone: "Australia/Sydney", name: "Australian Eastern Daylight Time", generic: "Eastern Australia Time"),
        .init(code: "NZST", minutes: 720, zone: "Pacific/Auckland", name: "New Zealand Standard Time", generic: "New Zealand Time"),
        .init(code: "NZDT", minutes: 780, zone: "Pacific/Auckland", name: "New Zealand Daylight Time", generic: "New Zealand Time"),
    ]
}
