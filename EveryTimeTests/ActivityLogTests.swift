import Foundation
import Testing
@testable import EveryTime

struct ActivityLogTests {
    init() { useDefaultCycle() }

    private let calendar = gregorian()

    private func log(_ marks: [(Date, String?)]) -> ActivityLog {
        ActivityLog(marks: marks.map { ActivityMark(time: $0.0, tag: $0.1) }, calendar: gregorian())
    }

    @Test func eachMarkRunsUntilTheNextAndTheLastStaysOpen() {
        let spans = log([(date(2026, 9, 28, 9), "work"), (date(2026, 9, 28, 8), "eat")])
            .spans(at: date(2026, 9, 28, 10))
        #expect(spans.map(\.tag) == ["eat", "work"])
        #expect(spans[0].duration == 3600)
        #expect(spans[1].isOpen && spans[1].duration == 3600)
    }

    @Test func oldWakeUpPinsBecomeSleepEndsOrGo() {
        let marks = [(date(2026, 9, 27, 23), "sleep"), (date(2026, 9, 28, 7), "wake"), (date(2026, 9, 28, 9), "work"), (date(2026, 9, 28, 10), "wake")]
            .map { ActivityMark(time: $0.0, tag: $0.1) }
        let kept = ActivityLog.migrateTags(marks + [ActivityMark(time: date(2026, 9, 28, 14), tag: "nap")])
        #expect(kept.map(\.tag) == ["sleep", nil, "work", "sleep"])
    }

    @Test func coffeeIsAMomentAndDoesNotSplitTheDay() {
        let log = log([(date(2026, 9, 28, 9), "work"), (date(2026, 9, 28, 10), "coffee")])
        let spans = log.spans(at: date(2026, 9, 28, 12))
        #expect(spans.map(\.tag) == ["work"])
        #expect(spans[0].isOpen && spans[0].duration == 3 * 3600)
        #expect(log.moments(at: date(2026, 9, 28, 12)).map(\.tag) == ["coffee"])
    }

    @Test func theLastMarkStopsAfterTwelveHours() {
        let spans = log([(date(2026, 9, 27, 15), "work")]).spans(at: date(2026, 9, 28, 10))
        #expect(!spans[0].isOpen)
        #expect(spans[0].end == date(2026, 9, 28, 3))
        #expect(log([(date(2026, 9, 27, 23), "sleep")]).spans(at: date(2026, 9, 28, 7))[0].isOpen)
    }

    @Test func todayCountsOnlyTheHoursAfterMidnight() {
        let log = log([(date(2026, 9, 27, 23), "sleep"), (date(2026, 9, 28, 7), "work"), (date(2026, 9, 28, 8), nil)])
        let now = date(2026, 9, 28, 9)
        let totals = log.totals(in: log.today(at: now), at: now)
        let sleep = totals.first(where: { $0.tag == "sleep" })?.time
        let untagged = totals.first(where: { $0.tag == nil })?.time
        #expect(sleep == TimeInterval(7 * 3600))
        #expect(untagged == TimeInterval(3600))
    }

    @Test func upSinceIsTheEndOfTheNightNotANap() {
        let log = log([
            (date(2026, 9, 27, 23, 30), "sleep"), (date(2026, 9, 28, 7), nil),
            (date(2026, 9, 28, 14), "sleep"), (date(2026, 9, 28, 14, 20), nil),
        ])
        #expect(log.upSince(at: date(2026, 9, 28, 16)) == date(2026, 9, 28, 7))
        #expect(log.nights(at: date(2026, 9, 28, 16)).count == 1)
        #expect(log.spans(at: date(2026, 9, 28, 16))[2].activity.title == "Nap")
    }

    @Test func typicalBedtimeAveragesAcrossMidnight() {
        let log = log([
            (date(2026, 9, 26, 23, 30), "sleep"), (date(2026, 9, 27, 7), nil),
            (date(2026, 9, 28, 0, 30), "sleep"), (date(2026, 9, 28, 8), nil),
        ])
        let typical = log.typical(at: date(2026, 9, 28, 12))
        #expect(typical.nights == 2)
        #expect(typical.bed == 0)
        #expect(typical.wake == 7 * 60 + 30)
        #expect(typical.sleep == 7.5 * 3600)
    }

    @Test func setTagKeepsRepeatAndAlarm() {
        let gym = ActivityMark(time: date(2026, 9, 28, 7), tag: "work", alarm: true, repeats: "daily")
        let mark = ActivityLog(marks: [gym], calendar: gregorian()).settingTag(gym.id, "fun").marks[0]
        #expect(mark.tag == "fun")
        #expect(mark.isDaily && mark.alarm == true)
    }

    @Test func momentDoesNotReuseSpanPin() {
        let now = date(2026, 9, 28, 9, 5)
        let coffee = Activity.of("coffee"), work = Activity.of("work")
        let afterWork = log([]).recording(work, at: date(2026, 9, 28, 9), starts: true, now: now)
            .recording(coffee, at: date(2026, 9, 28, 9), starts: true, now: now)
        #expect(afterWork.marks.map(\.tag) == ["work", "coffee"])
        let afterCoffee = log([]).recording(coffee, at: date(2026, 9, 28, 9), starts: true, now: now)
            .recording(work, at: date(2026, 9, 28, 9), starts: true, now: now)
        #expect(afterCoffee.marks.map(\.tag) == ["coffee", "work"])
    }

    @Test func aWrongTapIsFixedByTheRightTag() {
        let now = date(2026, 9, 28, 9, 5)
        let log = log([]).recording(Activity.of("work"), at: date(2026, 9, 28, 9), starts: true, now: now)
            .recording(Activity.of("fun"), at: date(2026, 9, 28, 9), starts: true, now: now)
        #expect(log.marks.map(\.tag) == ["fun"])
    }

    @Test func endingTagsTheRangeBeforeThePin() {
        let log = log([(date(2026, 9, 28, 13), nil)])
            .recording(.eat, at: date(2026, 9, 28, 14), starts: false, now: date(2026, 9, 28, 14, 5))
        #expect(log.marks.map(\.tag) == ["eat", nil])
        #expect(log.marks.map(\.time) == [date(2026, 9, 28, 13), date(2026, 9, 28, 14)])
    }

    @Test func twoHourNapIsNotANight() {
        #expect(log([(date(2026, 9, 28, 14), "sleep"), (date(2026, 9, 28, 16), nil)]).nights(at: date(2026, 9, 28, 17)).isEmpty)
    }

    @Test func backToBackSleepPinsAreOneNight() {
        let log = log([(date(2026, 9, 27, 23), "sleep"), (date(2026, 9, 28, 1), "sleep"), (date(2026, 9, 28, 2), nil)])
        let nights = log.nights(at: date(2026, 9, 28, 9))
        #expect(nights.count == 1)
        #expect(nights.first?.duration == TimeInterval(3 * 3600))
    }

    // MARK: Daily pins

    private func daily(_ hour: Int, _ tag: String, from: Int, alarm: Bool? = nil) -> ActivityLog {
        ActivityLog(marks: [], rules: [ActivityRule(hour: hour, minute: 0, tag: tag, alarm: alarm, from: from)], calendar: gregorian())
    }

    @Test func deletedRepeatStaysDeleted() {
        let log = daily(9, "work", from: 20261002)
        let rule = log.rules[0].id
        let saturday = ActivityLog.occurrenceID(rule, day: 20261003)
        let deleted = log.caughtUp(at: date(2026, 10, 3, 9, 30)).removing(saturday)
        let later = date(2026, 10, 3, 10)
        #expect(!deleted.isBehind(at: later))
        #expect(!deleted.caughtUp(at: later).spans(at: later).contains { $0.start == date(2026, 10, 3, 9) })
        #expect(deleted.spans(at: later).contains { $0.start == date(2026, 10, 2, 9) && $0.tag == "work" })

        let sunday = ActivityLog.occurrenceID(rule, day: 20261004)
        let skipped = deleted.removing(sunday)
        #expect(!skipped.planned(at: later).contains { $0.id == sunday })
        let monday = date(2026, 10, 5, 12)
        #expect(skipped.caughtUp(at: monday).spans(at: monday).filter { $0.tag == "work" }.map(\.start)
                == [date(2026, 10, 2, 9), date(2026, 10, 5, 9)])

        let moved = deleted.detaching(sunday).saving(ActivityMark(id: sunday, time: date(2026, 10, 4, 10, 30), tag: "work"), at: later)
        let plans = moved.planned(at: later).filter { calendar.isDate($0.start, inSameDayAs: date(2026, 10, 4)) }
        #expect(plans.map(\.start) == [date(2026, 10, 4, 10, 30)])
        #expect(moved.caughtUp(at: monday).spans(at: monday).contains { $0.start == date(2026, 10, 4, 10, 30) })
    }

    @Test func dailyPinOlderThan14Days() {
        let gym = ActivityMark(time: date(2026, 9, 1, 9), tag: "workout", repeats: "daily")
        let morning = date(2026, 9, 21, 8)
        let log = ActivityLog(marks: [gym], calendar: gregorian()).migratingRepeats(at: morning)
        #expect(log.planned(at: morning).contains { $0.start == date(2026, 9, 22, 9) && $0.isDaily })
        let later = date(2026, 9, 21, 10)
        #expect(log.spans(at: later).contains { $0.start == date(2026, 9, 21, 9) && $0.tag == "workout" })
        let december = date(2026, 12, 1, 8)
        #expect(log.planned(at: december).contains { $0.start == date(2026, 12, 1, 9) })
        #expect(log.caughtUp(at: december).spans(at: december).contains { $0.start == date(2026, 11, 30, 9) })
    }

    @Test func dailyPinKeepsItsClockTimeAcrossDST() {
        let log = ActivityLog(marks: [], rules: [ActivityRule(hour: 9, minute: 0, tag: "work", alarm: nil, from: 20261031)],
                              calendar: gregorian(newYork))
        let starts = log.planned(at: date(2026, 10, 30, 12, in: newYork)).map(\.start).prefix(3)
        #expect(Array(starts) == [date(2026, 10, 31, 9, in: newYork), date(2026, 11, 1, 9, in: newYork), date(2026, 11, 2, 9, in: newYork)])
    }

    @Test func oldDailyPinsBecomeRulesOnce() {
        let now = date(2026, 9, 5, 12)
        let gym = ActivityMark(time: date(2026, 9, 1, 7), tag: "workout", alarm: true, repeats: "daily")
        // Sep 3 was deleted; Sep 5 is still owed.
        let copies = [date(2026, 9, 2, 7), date(2026, 9, 4, 7)].map { ActivityMark(time: $0, tag: "workout") }
        let old = ActivityLog(marks: [gym] + copies, calendar: gregorian())
        let log = old.migratingRepeats(at: now)
        #expect(log.marks.map(\.time).sorted() == [1, 2, 4, 5].map { date(2026, 9, $0, 7) })
        #expect(!log.marks.contains { $0.isDaily })
        #expect(log.marks.first { $0.id == gym.id }?.alarm == true)
        #expect(log.rules.count == 1)
        let rule = log.rules[0]
        #expect(rule.hour == 7 && rule.minute == 0 && rule.tag == "workout" && rule.alarm == true)
        #expect(rule.from == 20260906)

        let again = log.migratingRepeats(at: now)
        #expect(again.marks == log.marks && again.rules == log.rules)
        let restoredOld = ActivityLog(marks: old.marks, rules: log.rules, calendar: gregorian()).migratingRepeats(at: now)
        #expect(restoredOld.rules == log.rules)
    }

    @Test func storedRepeatsMigrateIntoBothKeys() throws {
        let suite = "EveryTimeTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.encode([ActivityMark(time: date(2026, 9, 1, 7), tag: "workout", repeats: "daily")], ActivityLog.key)
        ActivityLog.migrateRepeats(in: defaults, now: date(2026, 9, 1, 8))
        let rulesData = defaults.data(forKey: ActivityLog.rulesKey)
        ActivityLog.migrateRepeats(in: defaults, now: date(2026, 9, 1, 8))
        let stored = ActivityLog.stored(in: defaults)
        #expect(stored.rules.count == 1 && !stored.marks.contains { $0.isDaily })
        #expect(defaults.data(forKey: ActivityLog.rulesKey) == rulesData)
        #expect(BackupSnapshot.isBackedUp(ActivityLog.rulesKey))
    }

    @Test func turningOffRepeatRemovesItsAlarm() {
        let now = date(2026, 10, 1, 12)
        let log = daily(9, "workout", from: 20261002, alarm: true)
        let rule = log.rules[0]
        let alarms = ActivityAlarms.wanted(log, at: now)
        #expect(alarms.count == ActivityAlarms.dailyDays)
        #expect(alarms.first?.fire == date(2026, 10, 2, 9))

        #expect(ActivityAlarms.wanted(log.removing(rule.id), at: now).isEmpty)
        #expect(ActivityAlarms.wanted(log.togglingAlarm(rule.id), at: now).isEmpty)
        let off = log.saving(ActivityMark(id: rule.id, time: date(2026, 10, 2, 9), tag: "workout", alarm: true), at: now)
        #expect(off.rules.isEmpty)
        #expect(ActivityAlarms.wanted(off, at: now).map(\.fire) == [date(2026, 10, 2, 9)])
        #expect(!ActivityAlarms.wanted(off, at: now).contains { alarms.map(\.id).contains($0.id) })

        let skipped = log.removing(ActivityLog.occurrenceID(rule.id, day: 20261003))
        #expect(!ActivityAlarms.wanted(skipped, at: now).contains { $0.fire == date(2026, 10, 3, 9) })
    }

    @Test func retaggingAPlannedDayLeavesTheRestDaily() {
        let log = daily(9, "work", from: 20261002)
        let friday = ActivityLog.occurrenceID(log.rules[0].id, day: 20261002)
        let now = date(2026, 10, 1, 12)
        let retagged = log.recording(.of("fun"), at: date(2026, 10, 2, 9), starts: true, now: now)
        let plans = retagged.planned(at: now).prefix(2)
        #expect(plans.map(\.tag) == ["fun", "work"])
        #expect(plans.first?.id == friday && plans.first?.isDaily == false)
    }
}
