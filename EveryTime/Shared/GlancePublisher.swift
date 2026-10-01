import WatchConnectivity
import WidgetKit

/// Copies cities and countdowns to the App Group (widget) and the watch whenever they change.
final class GlancePublisher: NSObject, WCSessionDelegate {
    static let shared = GlancePublisher()
    private var last: Glance?

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    @MainActor
    func publish() {
        guard AppData.drivesSystem else { return }
        let glance = Glance.current(defaults: AppData.defaults)
        guard glance != last else { return }
        last = glance
        glance.save()
        WidgetCenter.shared.reloadAllTimelines()
        sendToWatch(glance)
    }

    private func sendToWatch(_ glance: Glance) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled,
              let data = try? JSONEncoder().encode(glance) else { return }
        try? session.updateApplicationContext([Glance.key: data])
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            last = nil
            publish()
        }
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            last = nil
            publish()
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
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
