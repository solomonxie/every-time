import Observation
import WatchConnectivity

/// Latest Glance from the phone, kept on the watch so it shows without the phone nearby.
@Observable
final class WatchStore: NSObject, WCSessionDelegate {
    private(set) var glance = Glance.load(from: .standard)

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    private func receive(_ context: [String: Any]) {
        guard let data = context[Glance.key] as? Data,
              let glance = try? JSONDecoder().decode(Glance.self, from: data) else { return }
        glance.save(to: .standard)
        Task { @MainActor in self.glance = glance }
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        receive(session.receivedApplicationContext)
    }

    func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        receive(context)
    }
}
