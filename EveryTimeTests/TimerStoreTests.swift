import Foundation
import UserNotifications
import Testing
@testable import EveryTime

struct TimerStoreTests {
    @Test func clockStateSurvivesRelaunch() throws {
        let suite = "EveryTimeTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = TimerStore(defaults: defaults)
        store.leetcode.clock.start()
        store.leetcode.problem = "1. Two Sum"
        store.leetcode.difficulty = .hard
        store.interview.start()
        store.interview.pause()
        store.stopwatch.clock.start()
        store.stopwatch.lap()

        let later = Date.now.addingTimeInterval(1800)
        let relaunched = TimerStore(defaults: defaults)
        #expect(relaunched.leetcode.clock.isRunning)
        #expect(abs(relaunched.leetcode.clock.elapsed(at: later) - store.leetcode.clock.elapsed(at: later)) < 0.001)
        #expect(relaunched.leetcode.problem == "1. Two Sum")
        #expect(relaunched.leetcode.difficulty == .hard)
        #expect(!relaunched.interview.isRunning)
        #expect(relaunched.interview.elapsed(at: later) == store.interview.elapsed(at: later))
        #expect(relaunched.stopwatch.laps == store.stopwatch.laps)
        #expect(!relaunched.rehearsal.hasTime)

        relaunched.leetcode.clock.reset()
        #expect(!TimerStore(defaults: defaults).leetcode.clock.hasTime)
    }

    @Test func liveTimersStayOutOfBackups() {
        #expect(!BackupSnapshot.isBackedUp(TimerStore.liveKey))
    }
}

struct TimesUpTests {
    @Test func timesUpNotificationDelay() throws {
        let now = date(2026, 10, 1, 9)
        let running = ElapsedClock.State(startedAt: now.addingTimeInterval(-300), accumulated: 300)
        let request = try #require(TimerStore.timesUp(.interview, running, minutes: 45, now: now))
        #expect(request.fire == now.addingTimeInterval(35 * 60))
        #expect(request.feature == .timer && request.timeSensitive)
        let trigger = try #require(request.notification(now: now).trigger as? UNTimeIntervalNotificationTrigger)
        #expect(abs(trigger.timeInterval - 35 * 60) < 0.001)

        let paused = ElapsedClock.State(startedAt: nil, accumulated: 600)
        #expect(TimerStore.timesUp(.interview, paused, minutes: 45, now: now) == nil)
        let pending = [NotificationBudget.Pending(id: request.id, fingerprint: request.fingerprint, fire: request.fire)]
        #expect(NotificationBudget.diff(pending: pending, wanted: [], now: now).remove == [request.id])

        let over = ElapsedClock.State(startedAt: now.addingTimeInterval(-11 * 60), accumulated: 0)
        #expect(TimerStore.timesUp(.rehearsal, over, minutes: 10, now: now) == nil)
        #expect(TimerStore.timesUp(.rehearsal, running, minutes: 10, now: now)?.id != request.id)
    }
}
