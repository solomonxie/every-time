import Foundation
import Testing
@testable import EveryTime

/// Usual 23:00 → 07:00; nap window 13:00–15:30 on 2026-03-10.
struct SleepNowTests {
    private func sleepNow(_ start: Date) -> SleepNow { SleepNow(advice: napAdvice(), start: start) }

    private func recommended(_ options: [SleepNow.Option]) -> [String] { options.filter(\.isRecommended).map(\.id) }

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
        #expect(now.isDaytime)
        #expect(now.napOptions.map(\.id) == ["nap10", "nap20", "nap30", "nap90"])
        #expect(recommended(now.napOptions) == ["nap20"])
        #expect(now.napVerdict.headline == "Early for a nap")
        #expect(now.sleepOptions.isEmpty)
        #expect(now.sleepVerdict.headline == "Too early for bed")
        #expect(now.tip == nil)
    }

    @Test func napWindow() {
        let now = sleepNow(date(2026, 3, 10, 14))
        #expect(recommended(now.napOptions) == ["nap20"])
        #expect(now.napVerdict.headline == "Good time for a nap")
        #expect(now.napVerdict.reason == "20 min refreshes without grogginess.")
        let nap = now.napOptions.first { $0.id == "nap20" }!
        #expect(nap.time == date(2026, 3, 10, 14, 20))
        #expect(nap.level == .low)
    }

    @Test func napWindowBeforeLateNightSuggestsFullCycle() {
        let plan = tonightPlan(bed: 60, wake: 8 * 60)
        let now = SleepNow(advice: napAdvice(plan: plan), start: date(2026, 3, 10, 14))
        #expect(recommended(now.napOptions) == ["nap90"])
    }

    @Test func eveningFarFromBedWarnsOfSplitNight() {
        let now = sleepNow(date(2026, 3, 10, 18))
        #expect(!now.isDaytime)
        #expect(now.sleepOptions.map(\.id) == ["bed", "split"])
        #expect(recommended(now.sleepOptions) == ["bed"])
        #expect(now.sleepOptions.map(\.kind) == [
            .bedAt(date(2026, 3, 10, 21, 45)),
            .splitNight(wakeFrom: date(2026, 3, 10, 22, 45), wakeTo: date(2026, 3, 11, 0, 15)),
        ])
        #expect(now.sleepVerdict.headline == "Risk of a split night")
        #expect(recommended(now.napOptions) == ["nap20"])
        #expect(now.napVerdict.headline == "Late for a nap")
    }

    @Test func eveningNearBedPrefersBedEarlier() {
        let now = sleepNow(date(2026, 3, 10, 21))
        #expect(now.sleepOptions.map(\.id) == ["bed", "night6"])
        #expect(recommended(now.sleepOptions) == ["bed"])
        #expect(now.sleepOptions[1].kind == .night(cycles: 6, wake: date(2026, 3, 11, 6, 15)))
        #expect(now.sleepVerdict.headline == "Close to bedtime")
        #expect(now.sleepVerdict.reason == "Stay up until \(SleepNow.clock(date(2026, 3, 10, 21, 45))), or make it an early night.")
        #expect(recommended(now.napOptions).isEmpty)
        #expect(now.napVerdict.headline == "Too late for a nap")
    }

    @Test func bedtimePicksLongestWakeBeforePlannedWake() {
        let now = sleepNow(date(2026, 3, 10, 22))
        #expect(now.zone == .bedtime)
        #expect(now.sleepOptions.map(\.id) == ["night6", "night5", "night4", "night3"])
        #expect(now.sleepOptions.map(\.time) == [date(2026, 3, 11, 7, 15), date(2026, 3, 11, 5, 45),
                                                 date(2026, 3, 11, 4, 15), date(2026, 3, 11, 2, 45)])
        #expect(recommended(now.sleepOptions) == ["night5"])
        #expect(now.sleepOptions[0].detail.hasSuffix("after your \(SleepNow.clock(date(2026, 3, 11, 7))) wake"))
        #expect(recommended(now.napOptions).isEmpty)
        #expect(now.napVerdict.headline == "Bedtime, not nap time")
    }

    @Test func lateNightAllowsShortCycles() {
        let now = sleepNow(date(2026, 3, 11, 2))
        #expect(now.sleepOptions.map(\.id) == ["night3", "night2", "night1"])
        #expect(recommended(now.sleepOptions) == ["night3"])
        #expect(now.sleepOptions.map(\.level) == [.some, .high, .high])
        #expect(now.sleepVerdict.headline == "Past bedtime")
        #expect(now.tip != nil)
    }

    @Test func underACycleLeftFallsBackToNap() {
        let now = sleepNow(date(2026, 3, 11, 6))
        #expect(now.sleepOptions.isEmpty)
        #expect(now.sleepVerdict.reason.hasPrefix("Under a cycle left"))
        #expect(recommended(now.napOptions) == ["nap20"])
        #expect(now.napVerdict.headline == "Short on time")
    }

    @Test func daytimeAnswersWithNaps() {
        let now = sleepNow(date(2026, 3, 10, 14))
        #expect(now.options.map(\.id) == ["nap10", "nap20", "nap30", "nap90"])
        #expect(recommended(now.options) == ["nap20"])
        #expect(now.verdict.headline == now.napVerdict.headline)
    }

    @Test func eveningAnswersWithSleepThenGentleNaps() {
        let now = sleepNow(date(2026, 3, 10, 18))
        #expect(now.options.map(\.id) == ["bed", "split", "nap10", "nap20", "nap30"])
        #expect(recommended(now.options) == ["bed"])
        #expect(now.options.map(\.title).prefix(2) == ["Bed at \(SleepNow.clock(date(2026, 3, 10, 21, 45)))", "Sleep now"])
        #expect(now.verdict.headline == "Risk of a split night")
    }

    @Test func bedtimeAnswersWithNightsOnly() {
        let now = sleepNow(date(2026, 3, 10, 22))
        #expect(now.options.map(\.id) == ["night6", "night5", "night4", "night3"])
        #expect(now.options.map(\.caption).allSatisfy { $0 == "Wake at" })
    }

    @Test func lateNightWithNoCycleLeftAnswersWithAShortNap() {
        let now = sleepNow(date(2026, 3, 11, 6))
        #expect(recommended(now.options) == ["nap20"])
        #expect(now.options.allSatisfy { $0.level != .high })
    }
}
