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
        #expect(nap.caption == "20 · best")
        #expect(now.napOptions.map(\.caption) == ["10 min", "20 · best", "30 · groggy", "90 · full cycle"])
    }

    @Test func eveningFarFromBedWarnsOfSplitNight() {
        let now = sleepNow(date(2026, 3, 10, 18))
        #expect(!now.isDaytime)
        #expect(now.sleepOptions.map(\.id) == ["split"])
        #expect(recommended(now.sleepOptions).isEmpty)
        #expect(now.sleepOptions[0].kind == .splitNight(wakeFrom: date(2026, 3, 10, 22, 45), wakeTo: date(2026, 3, 11, 0, 15)))
        #expect(now.sleepVerdict.headline == "Risk of a split night")
        #expect(now.bedBy?.time == date(2026, 3, 10, 21, 45))
        #expect(recommended(now.napOptions) == ["nap20"])
        #expect(now.napVerdict.headline == "Late for a nap")
    }

    @Test func eveningNearBedSleepsForTheNight() {
        let now = sleepNow(date(2026, 3, 10, 21))
        #expect(now.sleepOptions.map(\.id) == ["night6"])
        #expect(recommended(now.sleepOptions) == ["night6"])
        #expect(now.sleepOptions[0].kind == .night(cycles: 6, wake: date(2026, 3, 11, 6, 15)))
        #expect(now.sleepVerdict.headline == "Close to bedtime")
        #expect(now.sleepVerdict.reason == "Bed by \(SleepNow.clock(date(2026, 3, 10, 21, 45))) for 6 cycles before \(SleepNow.clock(date(2026, 3, 11, 7))).")
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
        // 7:15 is within the 15-min slack of the 7:00 wake: not "sleep in", but not the pick either.
        #expect(!now.sleepOptions[0].isLate)
        #expect(now.sleepOptions[0].caption == "6 cycles")
        #expect(now.sleepOptions[1].caption == "5 · best")
        #expect(now.sleepOptions[2].caption == "4 cycles")
        #expect(now.sleepOptions[1].sleepMinutes(from: now.start) == 465)
        #expect(now.sleepVerdict.headline == "Bedtime")
        #expect(recommended(now.napOptions).isEmpty)
        #expect(now.napVerdict.headline == "Bedtime, not nap time")
    }

    @Test func lateNightAllowsShortCyclesAndSleepingIn() {
        let now = sleepNow(date(2026, 3, 11, 2))
        #expect(now.sleepOptions.map(\.id) == ["night6", "night5", "night4", "night3", "night2", "night1"])
        #expect(recommended(now.sleepOptions) == ["night3"])
        #expect(now.sleepOptions.map(\.level) == [.low, .low, .some, .some, .high, .high])
        #expect(now.sleepOptions[0].detail.hasSuffix("after your \(SleepNow.clock(date(2026, 3, 11, 7))) wake"))
        #expect(now.sleepVerdict.headline == "Past bedtime")
        #expect(now.tip != nil)
    }

    @Test func underACycleLeftFallsBackToNap() {
        let now = sleepNow(date(2026, 3, 11, 6))
        #expect(recommended(now.sleepOptions).isEmpty)
        #expect(now.sleepVerdict.reason.hasPrefix("Under a cycle left"))
        #expect(recommended(now.napOptions) == ["nap20"])
        #expect(now.napVerdict.headline == "Short on time")
    }

    @Test func daytimeChipsAreNaps() {
        let now = sleepNow(date(2026, 3, 10, 14))
        #expect(now.options.map(\.id) == ["nap10", "nap20", "nap30", "nap90"])
        #expect(now.pick?.id == "nap20")
        #expect(now.verdict.headline == now.napVerdict.headline)
    }

    @Test func eveningChipsAreTheShortNapThenTheNight() {
        let now = sleepNow(date(2026, 3, 10, 18))
        #expect(now.options.map(\.id) == ["nap20", "split"])
        #expect(now.pick?.id == "nap20")
        #expect(now.verdict.headline == "Risk of a split night")
    }

    @Test func bedtimeChipsAreEarliestFirst() {
        let now = sleepNow(date(2026, 3, 10, 22))
        // A nap this close to bed is .high, so none is offered.
        #expect(now.options.map(\.id) == ["night3", "night4", "night5", "night6"])
        #expect(now.pick?.id == "night5")
    }

    @Test func lateNightWithNoCycleLeftPicksAShortNap() {
        let now = sleepNow(date(2026, 3, 11, 6))
        #expect(now.pick?.id == "nap20")
    }
}

struct WakeChoiceTests {
    @Test func nightChoice() {
        let now = date(2026, 3, 10, 23, 20)
        let choice = WakeChoice(now: now, bed: now, wake: date(2026, 3, 11, 6, 35))
        #expect(choice.isNow && !choice.isNap)
        #expect(choice.minutes == 435)
        #expect(choice.cycles == 4.666666666666667)
        #expect(choice.button.hasPrefix("Sleep now · up at"))
        #expect(choice.fitLine.hasPrefix("7h 15m · 4.7 cycles · "))
    }

    @Test func napChoice() {
        let now = date(2026, 3, 10, 14, 10)
        let choice = WakeChoice(now: now, bed: now, wake: date(2026, 3, 10, 14, 30))
        #expect(choice.isNap)
        #expect(choice.button.hasPrefix("Nap now · up at"))
        #expect(choice.fitLine == "20m · 20-min nap · Wakes before deep sleep")
    }

    @Test func bedLaterPlansInstead() {
        let now = date(2026, 3, 10, 21)
        let choice = WakeChoice(now: now, bed: date(2026, 3, 10, 23), wake: date(2026, 3, 11, 6, 35))
        #expect(!choice.isNow)
        #expect(choice.minutes == 455)
        #expect(choice.button.hasPrefix("Bed at "))
        #expect(choice.symbol == "bed.double.fill")
    }
}
