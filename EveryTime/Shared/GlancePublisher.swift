import WidgetKit

/// Copies cities and countdowns to the App Group for the widget whenever they change.
final class GlancePublisher {
    static let shared = GlancePublisher()
    private var last: Glance?

    @MainActor
    func publish() {
        guard AppData.drivesSystem else { return }
        let glance = Glance.current(defaults: AppData.defaults)
        guard glance != last else { return }
        last = glance
        glance.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}

extension Glance {
    static func current(defaults: UserDefaults = .standard) -> Glance {
        func decode<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
            defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(type, from: $0) }
        }
        let cities = decode([WorldCity].self, WorldCity.storageKey) ?? WorldCity.defaults
        let countdowns = (decode([EveryTime.Countdown].self, EveryTime.Countdown.storageKey) ?? [])
            .map { Glance.Countdown(id: $0.id, name: $0.name, target: $0.target) }
        return Glance(cities: cities, countdowns: countdowns)
    }
}
