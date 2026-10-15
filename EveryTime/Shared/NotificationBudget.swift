import UserNotifications

/// iOS keeps at most 64 pending local notifications. Each feature says what it wants; one serial pass
/// shares the slots out and changes only the pending requests that differ.
@MainActor
enum NotificationBudget {
    nonisolated static let systemCap = 64

    enum Feature: CaseIterable {
        case nap, windDown, timer, activity, countdown, event, lunar, jetLag

        var prefix: String {
            switch self {
            case .nap: "nap."
            case .windDown: "sleep.winddown"
            case .timer: "timer."
            case .activity: "activity."
            case .countdown: "countdown."
            case .event: "important."
            case .lunar: "lunar."
            case .jetLag: "jetlag."
            }
        }

        /// Held even when unused, so a nap, wind-down or timer always fits.
        var reserve: Int {
            switch self {
            case .nap: 9
            case .windDown: 1
            case .timer: 2
            default: 0
            }
        }

        /// The soonest few kept even when other features fill the rest earlier.
        var minimum: Int {
            switch self {
            case .activity, .jetLag: 8
            case .countdown, .event: 4
            case .lunar: 2
            default: 0
            }
        }

        /// The nap chain is scheduled by `NapAlarm`; the budget only holds its slots.
        var isManaged: Bool { self != .nap }

        static func managing(_ id: String) -> Bool {
            allCases.contains { $0.isManaged && id.hasPrefix($0.prefix) }
        }
    }

    struct Request: Equatable {
        let id: String
        let feature: Feature
        let fire: Date
        var title: String
        var body = ""
        var sound = true
        var timeSensitive = false
        /// A wall-clock time (9:00 on a day) that follows the phone's zone; otherwise an absolute instant.
        var floating = false

        var fingerprint: String {
            "\(Int(fire.timeIntervalSince1970))|\(floating)|\(sound)|\(timeSensitive)|\(title)|\(body)"
        }

        func notification(now: Date, calendar: Calendar = .current) -> UNNotificationRequest {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = sound ? .default : nil
            if timeSensitive { content.interruptionLevel = .timeSensitive }
            content.userInfo = [fingerprintKey: fingerprint, fireKey: fire.timeIntervalSince1970]
            let trigger: UNNotificationTrigger = floating
                ? UNCalendarNotificationTrigger(dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fire),
                                                repeats: false)
                : UNTimeIntervalNotificationTrigger(timeInterval: max(1, fire.timeIntervalSince(now)), repeats: false)
            return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        }
    }

    struct Pending: Equatable {
        let id: String
        var fingerprint: String?
        var fire: Date?
    }

    private nonisolated static let fingerprintKey = "budget.fingerprint"
    private nonisolated static let fireKey = "budget.fire"
    /// A request this close to firing is left alone, so a pause at zero can't swallow its own time's-up.
    private nonisolated static let firing: TimeInterval = 2
    private static let queue = SerialScheduler()
    private static var asking = false
    /// The id of a notification whose own screen is up and celebrates in place, e.g. an open countdown.
    static var showing: String?

    static func register() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    /// While the app is open: everything shows, except a nap alarm the app is already ringing and what its open screen shows.
    nonisolated static func presentation(for id: String, category: String = "", napRinging: Bool = false,
                                         showing: String? = nil) -> UNNotificationPresentationOptions {
        if category == NapAlarm.category { return napRinging ? [] : [.banner, .sound, .list] }
        return id == showing ? [] : [.banner, .sound, .list]
    }

    /// Re-plans every feature's notifications; a later call supersedes one still waiting.
    static func refresh(requestingAuthorization: Bool = false) {
        guard AppData.drivesSystem, !AppData.isTestHost else { return }
        asking = asking || requestingAuthorization
        queue.enqueue { token in
            let center = UNUserNotificationCenter.current()
            let now = Date.now
            let kept = allocate(wanted(now: now))
            let pending = await center.pendingNotificationRequests().map(parse)
            guard queue.isCurrent(token) else { return }
            let change = diff(pending: pending, wanted: kept, now: now)
            center.removePendingNotificationRequests(withIdentifiers: change.remove)
            guard !change.add.isEmpty else { return }
            let ask = asking
            asking = false
            guard await isAuthorized(center, requesting: ask), queue.isCurrent(token) else { return }
            for request in change.add {
                try? await center.add(request.notification(now: .now))
                guard queue.isCurrent(token) else { return }
            }
        }
    }

    private static func wanted(now: Date) -> [Request] {
        TimerStore.wanted(now: now)
            + WindDown.wanted(now: now)
            + ActivityAlarms.wanted(now: now)
            + CountdownNotifications.wanted(now: now)
            + ImportantEventNotifications.wanted(now: now)
            + LunarNotifications.wanted(now: now)
            + JetLagNotifications.wanted(now: now)
    }

    /// Reserved features first, then each feature's minimum, then the soonest of the rest.
    nonisolated static func allocate(_ wanted: [Request], capacity: Int = systemCap) -> [Request] {
        let byFeature = Dictionary(grouping: wanted, by: \.feature).mapValues { $0.sorted { $0.fire < $1.fire } }
        var kept: [Request] = []
        var rest: [Request] = []
        var room = capacity
        for feature in Feature.allCases where feature.reserve > 0 {
            kept += (byFeature[feature] ?? []).prefix(feature.reserve)
            room -= feature.reserve
        }
        for feature in Feature.allCases where feature.reserve == 0 {
            let mine = byFeature[feature] ?? []
            let floor = max(0, min(feature.minimum, mine.count, room))
            kept += mine.prefix(floor)
            rest += mine.dropFirst(floor)
            room -= floor
        }
        return kept + rest.sorted { $0.fire < $1.fire }.prefix(max(0, room))
    }

    /// Adds what's new or changed (an add replaces the same id); removes managed requests no longer wanted.
    nonisolated static func diff(pending: [Pending], wanted: [Request], now: Date) -> (remove: [String], add: [Request]) {
        let have = Dictionary(pending.compactMap { p in p.fingerprint.map { (p.id, $0) } }, uniquingKeysWith: { first, _ in first })
        let keep = Set(wanted.map(\.id))
        let remove = pending
            .filter { Feature.managing($0.id) && !keep.contains($0.id) }
            .filter { $0.fire.map { $0.timeIntervalSince(now) > firing } ?? true }
            .map(\.id)
        let add = wanted.filter { have[$0.id] != $0.fingerprint }
        return (remove, add)
    }

    private nonisolated static func parse(_ request: UNNotificationRequest) -> Pending {
        let info = request.content.userInfo
        return Pending(id: request.identifier, fingerprint: info[fingerprintKey] as? String,
                       fire: (info[fireKey] as? Double).map(Date.init(timeIntervalSince1970:)))
    }

    private static func isAuthorized(_ center: UNUserNotificationCenter, requesting: Bool) async -> Bool {
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined where requesting:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        default:
            return false
        }
    }
}

/// Applies the budget's foreground policy, and handles "I'm up" from the lock screen.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let request = notification.request
        MainActor.assumeIsolated {
            completionHandler(NotificationBudget.presentation(for: request.identifier, category: request.content.categoryIdentifier,
                                                              napRinging: NapRinger.shared.isRinging, showing: NotificationBudget.showing))
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        MainActor.assumeIsolated {
            if response.notification.request.content.categoryIdentifier == NapAlarm.category,
               response.actionIdentifier == NapAlarm.upAction {
                NapSession.finish()
            }
        }
        completionHandler()
    }
}
