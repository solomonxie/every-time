import AVFoundation
import AlarmKit
import AudioToolbox
import SwiftUI
import UserNotifications

/// Starts, ends or drops the nap in progress; shared by the page and the alarm's "I'm up".
@MainActor
enum NapSession {
    /// Cancelling within this of lying down drops the sleep; after it the night is kept.
    static let cancelWindow: TimeInterval = 15 * 60

    static func start(minutes: Int) {
        resume(ActiveNap(start: .now, minutes: minutes))
    }

    /// Up at `wake`, from now.
    static func start(wake: Date) {
        start(minutes: max(1, Int((wake.timeIntervalSinceNow / 60).rounded())))
    }

    /// Bed later tonight: alarm at `wake`, wind-down reminder before bed; asleep from `bed` unless "I'm in bed now" comes first.
    static func plan(bed: Date, wake: Date) {
        let start = max(bed, .now)
        resume(ActiveNap(start: start, minutes: max(1, Int((wake.timeIntervalSince(start) / 60).rounded()))))
    }

    /// Going to bed earlier than planned: start now, same alarm.
    static func inBedNow() {
        guard var nap: ActiveNap = AppData.defaults.decoded(NapKey.active), nap.start > .now else { return }
        let alarm = nap.alarm
        unrecord(at: nap.start)
        nap.start = .now
        nap.minutes = max(1, Int((alarm.timeIntervalSince(nap.start) / 60).rounded()))
        ActivityLog.record(kind(nap.minutes), at: nap.start)
        AppData.defaults.encode(nap as ActiveNap?, NapKey.active)
        WindDown.cancel()
    }

    /// Makes `nap` the sleep in progress (or planned, when its start is ahead); also undoes a cancel.
    static func resume(_ nap: ActiveNap) {
        AppData.defaults.encode(nap as ActiveNap?, NapKey.active)
        ActivityLog.record(kind(nap.minutes), at: nap.start)
        WindDown.cancel()
        Task {
            await NapAlarm.schedule(nap)
            if nap.start.addingTimeInterval(-WindDown.lead) > .now { await WindDown.schedule(bed: nap.start) }
        }
    }

    /// What did's tag for any stretch of sleep; it reads as a nap by its length.
    static func kind(_ minutes: Int) -> Activity { .sleep }

    private static func unrecord(at time: Date) {
        ActivityLog.remove(.sleep, at: time)
    }

    static func canCancel(_ nap: ActiveNap, at now: Date = .now) -> Bool {
        now.timeIntervalSince(nap.start) <= cancelWindow
    }

    /// Stops the alarm; the sleep goes on and is logged at "I'm up".
    static func turnOffAlarm() {
        guard var nap: ActiveNap = AppData.defaults.decoded(NapKey.active) else { return }
        NapAlarm.cancel()
        nap.alarmOff = true
        AppData.defaults.encode(nap as ActiveNap?, NapKey.active)
    }

    /// Logs the sleep.
    static func finish(at end: Date = .now) {
        let defaults = AppData.defaults
        NapAlarm.cancel()
        guard let nap: ActiveNap = defaults.decoded(NapKey.active) else { return }
        guard end > nap.start else { cancel(); return }
        var naps: [Nap] = defaults.decoded(NapKey.naps) ?? []
        naps.insert(Nap(start: nap.start, end: max(end, nap.start)), at: 0)
        defaults.encode(naps, NapKey.naps)
        defaults.encode(nil as ActiveNap?, NapKey.active)
        unrecord(at: nap.start)
        ActivityLog.record(kind(Int(end.timeIntervalSince(nap.start) / 60)), at: nap.start)
        ActivityLog.record(nil, at: end)
    }

    /// Ends this stretch and starts another from now, so each wake keeps its own record.
    static func sleepMore(minutes: Int) {
        finish()
        start(minutes: minutes)
    }

    /// Rings at `time` instead, keeping the same start.
    static func moveAlarm(to time: Date) {
        guard var nap: ActiveNap = AppData.defaults.decoded(NapKey.active), time > .now else { return }
        nap.minutes = max(1, Int((time.timeIntervalSince(nap.start) / 60).rounded()))
        nap.alarmOff = nil
        AppData.defaults.encode(nap as ActiveNap?, NapKey.active)
        Task { await NapAlarm.schedule(nap) }
    }

    static func rate(_ id: UUID, energy: Int?) {
        let defaults = AppData.defaults
        var naps: [Nap] = defaults.decoded(NapKey.naps) ?? []
        guard let i = naps.firstIndex(where: { $0.id == id }) else { return }
        naps[i].energy = energy
        defaults.encode(naps, NapKey.naps)
    }

    /// Drops the sleep in progress; returns it so the cancel can be undone with `resume`.
    @discardableResult
    static func cancel() -> ActiveNap? {
        NapAlarm.cancel()
        WindDown.cancel()
        let nap: ActiveNap? = AppData.defaults.decoded(NapKey.active)
        if let nap { unrecord(at: nap.start) }
        AppData.defaults.encode(nil as ActiveNap?, NapKey.active)
        return nap
    }
}

/// Wakes you from a nap. iOS 26+: a system alarm. Before that: the app rings itself (through the
/// silent switch, kept alive by background audio), backed by a chain of time-sensitive notifications
/// in case the app is swiped away.
@MainActor
enum NapAlarm {
    enum Kind { case system, app }

    static let category = "nap.alarm"
    static let upAction = "nap.up"
    static let sound = "nap-alarm.caf"
    private static let chain = (0..<8).map { "nap.alarm.\($0)" }
    private static let bannerID = "nap.alarm.now"
    private static let chainGap: TimeInterval = 30
    private static let systemKey = "sleep.nap.alarm.system"

    static var kind: Kind { AppData.defaults.string(forKey: systemKey) == nil ? .app : .system }

    /// Delegate and "I'm up" action; call at launch so a tap from the lock screen is handled.
    static func register() {
        let center = UNUserNotificationCenter.current()
        center.delegate = NapNotificationDelegate.shared
        center.setNotificationCategories([
            UNNotificationCategory(identifier: category,
                                   actions: [UNNotificationAction(identifier: upAction, title: "I'm up")],
                                   intentIdentifiers: []),
        ])
    }

    static func schedule(_ nap: ActiveNap) async {
        cancel()
        if #available(iOS 26, *), let id = await SystemAlarm.schedule(nap) {
            AppData.defaults.set(id.uuidString, forKey: systemKey)
            return
        }
        NapRinger.shared.arm(for: nap)
        await scheduleChain(nap)
    }

    /// After a relaunch, re-arms the in-app ringer for a nap still under way.
    static func restore() {
        guard kind == .app, !NapRinger.shared.isArmed,
              let nap: ActiveNap = AppData.defaults.decoded(NapKey.active), nap.ringsAlarm, nap.alarm > .now
        else { return }
        NapRinger.shared.arm(for: nap)
    }

    static func cancel() {
        NapRinger.shared.stop()
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: chain + [bannerID])
        center.removeDeliveredNotifications(withIdentifiers: chain + [bannerID])
        if #available(iOS 26, *), let id = AppData.defaults.string(forKey: systemKey).flatMap(UUID.init) {
            SystemAlarm.cancel(id)
        }
        AppData.defaults.removeObject(forKey: systemKey)
    }

    /// The app is ringing, so the backup chain isn't needed; a silent banner keeps "I'm up" on the lock screen.
    static func ringerStarted() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: chain)
        guard UIApplication.shared.applicationState != .active else { return }
        let content = UNMutableNotificationContent()
        content.title = "Time to get up"
        content.body = "Your sleep is over."
        content.categoryIdentifier = category
        content.interruptionLevel = .timeSensitive
        center.add(UNNotificationRequest(identifier: bannerID, content: content, trigger: nil))
    }

    private static func scheduleChain(_ nap: ActiveNap) async {
        let center = UNUserNotificationCenter.current()
        switch await center.notificationSettings().authorizationStatus {
        case .notDetermined:
            guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
        case .denied:
            return
        default:
            break
        }
        for (i, id) in chain.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = i == 0 ? "Time to get up" : "Still asleep? Get up now"
            content.body = i == 0 ? "Your \(NapAdvice.hours(Double(nap.minutes) / 60)) of sleep is over." : "Sleeping on past a cycle's end leaves you groggier."
            content.sound = UNNotificationSound(named: UNNotificationSoundName(sound))
            content.categoryIdentifier = category
            content.interruptionLevel = .timeSensitive
            // A few seconds late, so a live ringer can cancel the chain first.
            let fire = nap.alarm.addingTimeInterval(5 + Double(i) * chainGap)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, fire.timeIntervalSinceNow), repeats: false)
            try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
    }

    static var notificationsDenied: Bool {
        get async { await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied }
    }
}

@available(iOS 26, *)
private enum SystemAlarm {
    struct Metadata: AlarmMetadata {}

    static func schedule(_ nap: ActiveNap) async -> UUID? {
        let manager = AlarmManager.shared
        let state = manager.authorizationState == .notDetermined
            ? (try? await manager.requestAuthorization()) : manager.authorizationState
        guard state == .authorized else { return nil }
        let alert: AlarmPresentation.Alert = if #available(iOS 26.1, *) {
            .init(title: "Time to get up")
        } else {
            .init(title: "Time to get up", stopButton: AlarmButton(text: "I'm up", textColor: .white, systemImageName: "sun.max"))
        }
        let attributes = AlarmAttributes<Metadata>(presentation: AlarmPresentation(alert: alert), tintColor: .indigo)
        let id = UUID()
        do {
            _ = try await manager.schedule(id: id, configuration: .alarm(schedule: .fixed(nap.alarm), attributes: attributes,
                                                                         sound: .named(NapAlarm.sound)))
            return id
        } catch {
            return nil
        }
    }

    static func cancel(_ id: UUID) {
        try? AlarmManager.shared.cancel(id: id)
    }
}

/// Rings the nap alarm from inside the app: playback audio ignores the silent switch, and a
/// muted loop until then keeps the app running in the background.
@MainActor @Observable
final class NapRinger {
    static let shared = NapRinger()
    private static let maxRing: TimeInterval = 10 * 60
    /// Audio session and player setup block for hundreds of ms; they stay off the main thread.
    private static let audio = DispatchQueue(label: "nap.ringer.audio")

    private(set) var isRinging = false
    private(set) var isArmed = false
    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var pending: DispatchWorkItem?
    @ObservationIgnored private var buzz: Timer?
    /// Bumped by `stop()` so an arm still in flight on the audio queue is dropped.
    @ObservationIgnored private var generation = 0

    private init() {
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { note in
            guard (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) == AVAudioSession.InterruptionType.ended.rawValue
            else { return }
            MainActor.assumeIsolated { NapRinger.shared.resume() }
        }
    }

    func arm(for nap: ActiveNap) {
        stop()
        guard let url = Bundle.main.url(forResource: NapAlarm.sound, withExtension: nil) else { return }
        isArmed = true
        let generation = generation
        Self.audio.async {
            Self.activateSession(mixing: true)
            guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
            player.numberOfLoops = -1
            player.volume = 0
            player.prepareToPlay()
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard self.generation == generation, self.isArmed else { return }
                    player.play()
                    self.player = player
                }
            }
        }
        after(nap.alarm.timeIntervalSinceNow) { $0.ring() }
    }

    func stop() {
        generation += 1
        pending?.cancel()
        buzz?.invalidate()
        let player = player
        self.player = nil
        isRinging = false
        isArmed = false
        Self.audio.async {
            player?.stop()
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func ring() {
        guard let player else { return }
        Self.audio.async { Self.activateSession(mixing: false) }
        player.currentTime = 0
        player.volume = 0.3
        player.play()
        player.setVolume(1, fadeDuration: 20)
        isRinging = true
        buzz = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
        NapAlarm.ringerStarted()
        after(Self.maxRing) { $0.stop() }
    }

    private func resume() {
        guard let player, isArmed else { return }
        let mixing = !isRinging
        Self.audio.async {
            Self.activateSession(mixing: mixing)
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard self.player === player else { return }
                    player.play()
                }
            }
        }
    }

    private nonisolated static func activateSession(mixing: Bool) {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: mixing ? [.mixWithOthers] : [.duckOthers])
        try? session.setActive(true)
    }

    private func after(_ delay: TimeInterval, _ action: @escaping (NapRinger) -> Void) {
        pending?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            MainActor.assumeIsolated { action(self) }
        }
        pending = item
        DispatchQueue.main.asyncAfter(wallDeadline: .now() + max(0, delay), execute: item)
    }
}

/// Handles "I'm up" from the lock screen, and keeps nap banners quiet while the app is ringing.
final class NapNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NapNotificationDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        guard notification.request.content.categoryIdentifier == NapAlarm.category else { return completionHandler([]) }
        MainActor.assumeIsolated {
            completionHandler(NapRinger.shared.isRinging ? [] : [.banner, .sound, .list])
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

extension UserDefaults {
    /// Values saved by `@Stored` (JSON), for code outside views.
    func decoded<T: Decodable>(_ key: String) -> T? {
        data(forKey: key).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }

    func encode<T: Encodable>(_ value: T, _ key: String) {
        set(try? JSONEncoder().encode(value), forKey: key)
    }
}
