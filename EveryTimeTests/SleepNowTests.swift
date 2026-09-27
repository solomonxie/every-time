import Foundation
import Testing
@testable import EveryTime

/// Usual 23:00 → 07:00; nap window 13:00–15:30 on 2026-03-10.
struct SleepNowTests {
    private func sleepNow(_ start: Date) -> SleepNow { SleepNow(advice: napAdvice(), start: start) }

    private func recommended(_ now: SleepNow) -> [String] { now.options.filter(\.isRecommended).map(\.id) }

    @Test func zones() {
        #expect(sleepNow(date(2026, 3, 10, 10)).zone == .beforeWindow)
        #expect(sleepNow(date(2026, 3, 10, 14)).zone == .napWindow)
        #expect(sleepNow(date(2026, 3, 10, 15, 30)).zone == .napWindow)
        #expect(sleepNow(date(2026, 3, 10, 18)).zone == .evening)
        #expect(sleepNow(date(2026, 3, 10, 21, 30)).zone == .bedtime)
        #expect(sleepNow(date(2026, 3, 11, 1)).zone == .lateNight)
        #expect(sleepNow(date(2026, 3, 11, 6)).zone == .lateNight)
    }

    @Test func smallHoursBelongToLastNight() {
        #expect(sleepNow(date(2026, 3, 11, 2)).day.wake == date(2026, 3, 10, 7))
    }

    @Test func beforeWindowSuggestsShortNap() {
        let now = sleepNow(date(2026, 3, 10, 10))
        #expect(now.options.map(\.id) == ["nap10", "nap20", "nap30", "nap90"])
        #expect(recommended(now) == ["nap20"])
        #expect(now.verdict.headline == "Early for a nap")
        #expect(now.tip == nil)
    }

    @Test func napWindow() {
        let now = sleepNow(date(2026, 3, 10, 14))
        #expect(recommended(now) == ["nap20"])
        #expect(now.verdict.headline == "Good time for a nap")
        #expect(now.verdict.reason == "20 min refreshes without grogginess.")
        let nap = now.options.first { $0.id == "nap20" }!
        #expect(nap.time == date(2026, 3, 10, 14, 20))
        #expect(nap.level == .low)
    }

    @Test func napWindowBeforeLateNightSuggestsFullCycle() {
        let plan = tonightPlan(bed: 60, wake: 8 * 60)
        let now = SleepNow(advice: napAdvice(plan: plan), start: date(2026, 3, 10, 14))
        #expect(recommended(now) == ["nap90"])
    }

    @Test func eveningFarFromBedWarnsOfSplitNight() {
        let now = sleepNow(date(2026, 3, 10, 18))
        #expect(now.options.map(\.id) == ["nap20", "nap90", "bed", "split"])
        #expect(recommended(now) == ["nap20"])
        let kinds = now.options.map(\.kind)
        #expect(kinds[2] == .bedAt(date(2026, 3, 10, 21, 45)))
        #expect(kinds[3] == .splitNight(wakeFrom: date(2026, 3, 10, 22, 45), wakeTo: date(2026, 3, 11, 0, 15)))
        #expect(now.verdict.headline == "Risk of a split night")
    }

    @Test func eveningNearBedPrefersBedEarlier() {
        let now = sleepNow(date(2026, 3, 10, 21))
        #expect(now.options.map(\.id) == ["nap20", "bed", "night6"])
        #expect(recommended(now) == ["bed"])
        #expect(now.options[2].kind == .night(cycles: 6, wake: date(2026, 3, 11, 6, 15)))
        #expect(now.verdict.headline == "Close to bedtime")
        #expect(now.verdict.reason == "Stay up until \(SleepNow.clock(date(2026, 3, 10, 21, 45))), or make it an early night.")
    }

    @Test func bedtimePicksLongestWakeBeforePlannedWake() {
        let now = sleepNow(date(2026, 3, 10, 22))
        #expect(now.zone == .bedtime)
        #expect(now.options.map(\.id) == ["night6", "night5", "night4", "night3"])
        #expect(now.options.map(\.time) == [date(2026, 3, 11, 7, 15), date(2026, 3, 11, 5, 45),
                                            date(2026, 3, 11, 4, 15), date(2026, 3, 11, 2, 45)])
        #expect(recommended(now) == ["night5"])
        #expect(now.options[0].detail.hasSuffix("after your \(SleepNow.clock(date(2026, 3, 11, 7))) wake"))
    }

    @Test func lateNightAllowsShortCycles() {
        let now = sleepNow(date(2026, 3, 11, 2))
        #expect(now.options.map(\.id) == ["night3", "night2", "night1"])
        #expect(recommended(now) == ["night3"])
        #expect(now.options.map(\.level) == [.some, .high, .high])
        #expect(now.verdict.headline == "Past bedtime")
        #expect(now.tip != nil)
    }

    @Test func underACycleLeftFallsBackToNap() {
        let now = sleepNow(date(2026, 3, 11, 6))
        #expect(now.options.map(\.id) == ["nap20"])
        #expect(recommended(now) == ["nap20"])
        #expect(now.verdict.reason.hasPrefix("Under a cycle left"))
    }

    @Test func napTimeline() {
        let now = sleepNow(date(2026, 3, 10, 14))
        let segments = now.segments(for: now.options.first { $0.id == "nap20" }!)
        #expect(segments == [
            .init(kind: .nap, start: date(2026, 3, 10, 14), end: date(2026, 3, 10, 14, 20)),
            .init(kind: .awake, start: date(2026, 3, 10, 14, 20), end: date(2026, 3, 10, 23)),
            .init(kind: .sleep, start: date(2026, 3, 10, 23), end: date(2026, 3, 11, 7)),
        ])
    }

    @Test func lateNapDriftsBedtime() {
        let now = sleepNow(date(2026, 3, 10, 18))
        let segments = now.segments(for: now.options.first { $0.id == "nap90" }!)
        #expect(segments.map(\.kind) == [.nap, .awake, .drift, .sleep])
        #expect(segments[2].end == date(2026, 3, 11, 0, 30))
    }

    @Test func splitNightTimeline() {
        let now = sleepNow(date(2026, 3, 10, 18))
        let segments = now.segments(for: now.options.first { $0.id == "split" }!)
        #expect(segments == [
            .init(kind: .sleep, start: date(2026, 3, 10, 18, 15), end: date(2026, 3, 10, 22, 45)),
            .init(kind: .restless, start: date(2026, 3, 10, 22, 45), end: date(2026, 3, 11, 1, 15)),
            .init(kind: .sleep, start: date(2026, 3, 11, 1, 15), end: date(2026, 3, 11, 7)),
        ])
    }

    @Test func nightTimeline() {
        let now = sleepNow(date(2026, 3, 10, 22))
        let segments = now.segments(for: now.options.first { $0.id == "night5" }!)
        #expect(segments == [
            .init(kind: .sleep, start: date(2026, 3, 10, 22, 15), end: date(2026, 3, 11, 5, 45)),
            .init(kind: .awake, start: date(2026, 3, 11, 5, 45), end: date(2026, 3, 11, 7)),
        ])
    }
}
