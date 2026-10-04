import Foundation
import UserNotifications

/// One notification before a chosen bedtime, to start winding down.
enum WindDown {
    static let lead: TimeInterval = 30 * 60
    private static let id = "sleep.winddown"

    static func schedule(bed: Date) async {
        let center = UNUserNotificationCenter.current()
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
        let content = UNMutableNotificationContent()
        content.title = "Time to wind down"
        content.body = "Lights low, screens off — in bed by \(SleepNow.clock(bed))."
        content.userInfo = ["bed": bed.timeIntervalSince1970]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, bed.addingTimeInterval(-lead).timeIntervalSinceNow), repeats: false)
        try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    /// The bedtime of the reminder still pending, if any.
    static func pending() async -> Date? {
        await UNUserNotificationCenter.current().pendingNotificationRequests()
            .first { $0.identifier == id }
            .flatMap { $0.content.userInfo["bed"] as? Double }
            .map { Date(timeIntervalSince1970: $0) }
    }
}
