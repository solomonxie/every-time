import Foundation
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
