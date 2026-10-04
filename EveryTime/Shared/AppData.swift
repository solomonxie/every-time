import Foundation

/// Where user data lives: the real store, or a separate demo store (More → Demo mode).
enum AppData {
    /// Kept in the real store, so turning demo mode off is always reachable.
    static let demoKey = "demo.on"

    static var isDemo: Bool { UserDefaults.standard.bool(forKey: demoKey) }

    static var defaults: UserDefaults { isDemo ? demoDefaults : .standard }

    static let demoSuite = (Bundle.main.bundleIdentifier ?? "everytime") + ".demo-data"
    static let demoDefaults = UserDefaults(suiteName: demoSuite) ?? .standard

    /// Notifications and widget show real data; demo mode inside the real app leaves them alone.
    static var drivesSystem: Bool { !isDemo }

    /// Seeds first, so views never see an empty demo store.
    @MainActor
    static func setDemo(_ on: Bool) {
        if on { DemoSeed.seed() }
        UserDefaults.standard.set(on, forKey: demoKey)
        if !on {
            CountdownNotifications.reschedule()
            ImportantEventNotifications.reschedule()
            LunarNotifications.reschedule()
            JetLagNotifications.reschedule()
            GlancePublisher.shared.publish()
        }
    }
}

/// Preset data from the bundled `demo/` folder, with dates relative to today.
///
/// Each `*.json` maps a store key to its value. `app-storage.json` holds plain `@AppStorage` values;
/// every other file holds `@Stored` (JSON) values. Strings like `"@today-1 23:40"`, `"@today 07:05"`,
/// `"@now-25m"`, `"@now+3h"`, `"@now+12d"` become dates.
enum DemoSeed {
    static let seededKey = "demo.seededDay"
    static let plainFile = "app-storage"

    /// Refreshed once a day, so "last night" and "today" stay true.
    static func seedIfNeeded(now: Date = .now) {
        guard AppData.demoDefaults.string(forKey: seededKey) != dayStamp(now) else { return }
        seed(now: now)
    }

    static func seed(now: Date = .now) {
        let defaults = AppData.demoDefaults
        guard defaults !== UserDefaults.standard else { return }
        defaults.removePersistentDomain(forName: AppData.demoSuite)
        for (key, value) in load(now: now) { defaults.set(value, forKey: key) }
        defaults.set(dayStamp(now), forKey: seededKey)
    }

    /// Key → value as UserDefaults stores it: Data for `@Stored`, plain values for `@AppStorage`.
    static func load(now: Date = .now, bundle: Bundle = .main) -> [String: Any] {
        let urls = bundle.urls(forResourcesWithExtension: "json", subdirectory: "demo") ?? []
        var out: [String: Any] = [:]
        for url in urls {
            guard let data = try? Data(contentsOf: url),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            let plain = url.deletingPathExtension().lastPathComponent == plainFile
            for (key, raw) in object {
                var value = resolve(raw, now: now)
                // The device's own zone is always shown first; listing it again would duplicate the row.
                if key == WorldCity.storageKey, let cities = value as? [[String: Any]] {
                    value = cities.filter { $0["timeZoneIdentifier"] as? String != TimeZone.current.identifier }
                }
                if plain {
                    out[key] = value
                } else if let encoded = try? JSONSerialization.data(withJSONObject: value, options: .fragmentsAllowed) {
                    out[key] = encoded
                }
            }
        }
        return out
    }

    /// Swaps relative date strings for seconds since 2001, the way `JSONEncoder` writes a Date.
    static func resolve(_ value: Any, now: Date, calendar: Calendar = .current) -> Any {
        switch value {
        case let string as String:
            return date(string, now: now, calendar: calendar)?.timeIntervalSinceReferenceDate ?? string
        case let array as [Any]:
            return array.map { resolve($0, now: now, calendar: calendar) }
        case let object as [String: Any]:
            return object.mapValues { resolve($0, now: now, calendar: calendar) }
        default:
            return value
        }
    }

    static func date(_ text: String, now: Date, calendar: Calendar = .current) -> Date? {
        guard let m = text.wholeMatch(of: #/@(today|now)(?:([+-]\d+)([mhd])?)?(?: (\d{1,2}):(\d{2}))?/#) else { return nil }
        let amount = m.2.flatMap { Int($0) } ?? 0
        if m.1 == "now" {
            guard m.4 == nil else { return nil }
            let unit: Double = switch m.3 { case "m": 60; case "h": 3600; case "d": 86_400; default: 0 }
            guard amount == 0 || unit > 0 else { return nil }
            return now.addingTimeInterval(Double(amount) * unit)
        }
        guard m.3 == nil || m.3 == "d",
              let day = calendar.date(byAdding: .day, value: amount, to: calendar.startOfDay(for: now)) else { return nil }
        guard let h = m.4.flatMap({ Int($0) }), let min = m.5.flatMap({ Int($0) }) else { return day }
        return calendar.date(bySettingHour: h, minute: min, second: 0, of: day)
    }

    private static func dayStamp(_ date: Date) -> String {
        date.formatted(.iso8601.year().month().day())
    }
}
