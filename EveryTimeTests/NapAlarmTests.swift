import Foundation
import Testing
@testable import EveryTime

@MainActor
struct NapAlarmTests {
    @Test func staleScheduleIsDropped() {
        let queue = SerialScheduler()
        let first = queue.begin()
        let second = queue.begin()
        #expect(!queue.isCurrent(first))
        #expect(queue.isCurrent(second))
        queue.invalidate()
        #expect(!queue.isCurrent(second))
    }

    @Test func onlyTheLatestQueuedJobRuns() async {
        let queue = SerialScheduler()
        var ran: [Int] = []
        queue.enqueue { _ in ran.append(1) }
        await withCheckedContinuation { done in
            queue.enqueue { _ in
                ran.append(2)
                done.resume()
            }
        }
        #expect(ran == [2])
    }

    @Test func stoppedSystemAlarmFinishesNap() {
        let nap = ActiveNap(start: date(2026, 3, 11, 14, 40), minutes: 20)
        let id = UUID()
        let late = date(2026, 3, 11, 17)
        #expect(NapAlarm.stoppedAt(active: nap, systemID: id, systemIDs: [], now: late) == nap.alarm)
        #expect(NapAlarm.stoppedAt(active: nap, systemID: id, systemIDs: [id], now: late) == nil)
        #expect(NapAlarm.stoppedAt(active: nap, systemID: id, systemIDs: [], now: date(2026, 3, 11, 14, 50)) == nil)
        #expect(NapAlarm.stoppedAt(active: nap, systemID: nil, systemIDs: [], now: late) == nil)
        var off = nap
        off.alarmOff = true
        #expect(NapAlarm.stoppedAt(active: off, systemID: id, systemIDs: [], now: late) == nil)
    }
}
