import Foundation
import Testing
@testable import EveryTime

struct LaborAnalysisTests {
    private let now = date(2026, 10, 18, 4)

    /// Contractions separated by `every`, the last one starting a minute before `end` (default now).
    private func series(every: [TimeInterval], length: TimeInterval = 60, strength: Contraction.Strength? = nil,
                        endingAt end: Date? = nil) -> [Contraction] {
        var start = (end ?? now).addingTimeInterval(-60)
        var result = [Contraction(start: start, end: start.addingTimeInterval(length), strength: strength)]
        for gap in every.reversed() {
            start = start.addingTimeInterval(-gap)
            result.append(Contraction(start: start, end: start.addingTimeInterval(length), strength: strength))
        }
        return result.reversed()
    }

    private func analysis(_ contractions: [Contraction], events: [LaborEvent] = [], settings: LaborSettings = LaborSettings(),
                          at time: Date? = nil) -> LaborAnalysis {
        LaborAnalysis(contractions: contractions, events: events, settings: settings, now: time ?? now, calendar: gregorian())
    }

    @Test func fiveOneOneMetAfterAnHourOfFiveMinuteMinuteLongContractions() {
        let a = analysis(series(every: Array(repeating: 290, count: 14), length: 62))
        #expect(a.ruleCheck.isMet)
        #expect(a.pattern.pattern == .activeLike)
    }

    @Test func fiveOneOneNotMetBeforeAnHour() {
        let a = analysis(series(every: Array(repeating: 290, count: 8), length: 62))
        #expect(!a.ruleCheck.isMet)
        #expect(a.ruleCheck.conditions.map(\.isMet) == [true, true, false])
    }

    @Test func fiveOneOneNeedsLengthAndCloseness() {
        let short = analysis(series(every: Array(repeating: 290, count: 14), length: 40))
        #expect(short.ruleCheck.conditions.map(\.isMet) == [true, false, true])
        let far = analysis(series(every: Array(repeating: 420, count: 10), length: 62))
        #expect(far.ruleCheck.conditions[0].isMet == false)
        #expect(far.pattern.pattern == .earlyLike)
    }

    @Test func oneMissedTapDoesNotBreakTheRule() {
        var gaps = Array(repeating: TimeInterval(280), count: 14)
        gaps[6] = 560
        #expect(analysis(series(every: gaps, length: 62)).ruleCheck.isMet)
    }

    @Test func misTapsAndForgottenStopsAreNotCounted() {
        var contractions = series(every: Array(repeating: 290, count: 14), length: 62)
        let tap = contractions[5].start.addingTimeInterval(100)
        contractions.append(Contraction(start: tap, end: tap.addingTimeInterval(2)))
        contractions[7].end = contractions[7].start.addingTimeInterval(600)
        let a = analysis(contractions)
        #expect(a.lastHour.lengths.allSatisfy { $0 == 62 })
        #expect(a.intervals[contractions[6].id] == 290)
        #expect(a.ruleCheck.isMet)
    }

    @Test func irregularMildNotCloserReadsAsBraxtonHicks() {
        let gaps: [TimeInterval] = [900, 300, 1500, 420, 1200, 600, 700, 1200, 300, 1500]
        let a = analysis(series(every: gaps, length: 35, strength: .mild))
        #expect(a.pattern.pattern == .braxtonHicksLike)
        #expect(a.pattern.reasons.contains { $0.sign == .practice && $0.text.hasPrefix("Irregular") })
        #expect(!a.ruleCheck.isMet)
    }

    @Test func pretermNeverReassuresAndFlags() {
        let gaps: [TimeInterval] = [900, 300, 1500, 420, 1200, 600, 700, 1200, 300, 1500]
        var settings = LaborSettings()
        settings.dueDate = date(2026, 12, 20)
        let a = analysis(series(every: gaps, length: 35, strength: .mild), settings: settings)
        #expect(a.isPreterm)
        #expect(a.pattern.pattern == .unclear)
        #expect(a.flags.contains { $0.id == "preterm" })
        #expect(a.advice.tone == .urgent)
        let quiet = analysis(series(every: [900, 900]), settings: settings)
        #expect(quiet.advice.headline == "Call your care team.")
    }

    @Test func gestationFromDueDate() throws {
        var settings = LaborSettings()
        settings.dueDate = date(2026, 10, 30)
        let gestation = try #require(settings.gestation(at: now, calendar: gregorian()))
        #expect(gestation.weeks == 38 && gestation.days == 2)
    }

    @Test func closingIntervalsReadAsLabor() {
        let gaps = Array(repeating: TimeInterval(480), count: 8) + Array(repeating: 270, count: 13)
        let a = analysis(series(every: gaps, length: 60, strength: .strong))
        #expect(a.pattern.reasons.contains { $0.sign == .labor && $0.text.hasPrefix("Closer") })
        #expect(a.pattern.pattern == .activeLike)
    }

    @Test func veryCloseTogether() {
        #expect(analysis(series(every: Array(repeating: 150, count: 30), length: 75)).pattern.pattern == .veryClose)
    }

    @Test func tooFewSaysKeepTiming() {
        let a = analysis(series(every: [300, 300]))
        #expect(a.pattern.pattern == .keepTiming(needed: 2))
    }

    @Test func easedAfterRestIsAPracticeSign() {
        let before = series(every: Array(repeating: 600, count: 6), length: 40, endingAt: now.addingTimeInterval(-40 * 60))
        let after = [Contraction(start: now.addingTimeInterval(-15 * 60), end: now.addingTimeInterval(-15 * 60 + 40))]
        let rested = LaborEvent(kind: .rested, time: now.addingTimeInterval(-39 * 60))
        let a = analysis(before + after, events: [rested])
        #expect(a.restEffect == LaborAnalysis.Reason(text: "Eased after rest", sign: .practice))

        let kept = series(every: Array(repeating: 600, count: 9), length: 40)
        let keptRest = LaborEvent(kind: .rested, time: now.addingTimeInterval(-45 * 60))
        #expect(analysis(kept, events: [keptRest]).restEffect?.sign == .labor)
    }

    @Test func nhsUrgentFlags() {
        let often = analysis(series(every: Array(repeating: 90, count: 6), length: 45))
        #expect(often.flags.contains { $0.id == "often" })
        let start = now.addingTimeInterval(-130)
        let long = analysis([Contraction(start: start)])
        #expect(long.flags.contains { $0.id == "long" })
    }

    @Test func eventFlags() {
        let events = [
            LaborEvent(kind: .waters, time: now.addingTimeInterval(-600), fluid: .greenBrown),
            LaborEvent(kind: .lessMovement, time: now.addingTimeInterval(-60)),
            LaborEvent(kind: .bleeding, time: now.addingTimeInterval(-30 * 3600)),
        ]
        let flags = analysis([], events: events).flags
        #expect(flags.map(\.id) == ["waters", "movement"])
        #expect(flags[0].text.contains("(green or brown)"))
    }

    @Test func episodesSplitOnALongGap() {
        let old = series(every: [300, 300], endingAt: now.addingTimeInterval(-5 * 3600))
        let current = series(every: [300])
        #expect(LaborAnalysis.episodes(old + current).map(\.count) == [2, 3])
        #expect(analysis(old + current).episode.count == 2)
        #expect(analysis(old).episode.isEmpty)
    }

    @Test func settingsDecodeWithMissingFields() throws {
        let settings = try JSONDecoder().decode(LaborSettings.self, from: Data(#"{"phone":"555"}"#.utf8))
        #expect(settings.phone == "555")
        #expect(settings.rule == .fiveOneOne)
        #expect(settings.firstBaby)
        #expect(!settings.setupDone)
    }

    @Test func oldCustomRuleBecomesTheCareTeamRule() throws {
        let json = #"{"rule":{"interval":240,"length":60,"window":3600},"firstBaby":true}"#
        let settings = try JSONDecoder().decode(LaborSettings.self, from: Data(json.utf8))
        #expect(settings.careTeamRule?.interval == 240)
        let back = try JSONDecoder().decode(LaborSettings.self, from: JSONEncoder().encode(settings))
        #expect(back == settings)
    }

    @Test func planFromAnswers() {
        var s = LaborSettings()
        #expect(s.plan.rule == .fiveOneOne)
        s.firstBaby = false
        #expect(s.plan.rule == .laterBaby)
        s.fastLastLabor = true
        #expect(s.plan.rule == .tenOneOne)
        s = LaborSettings()
        s.travelMinutes = 20
        s.transport = .rideshare
        #expect(s.leaveMinutes == 35)
        #expect(s.plan.rule == .tenOneOne)
        s.careTeamRule = LaborRule(interval: 240, length: 60, window: 3600)
        #expect(s.plan.rule.interval == 240)
        s.conditions = [.gbs, .breech]
        #expect(s.plan.firstSign == [.gbs, .breech])
        #expect(s.planSentence.contains("GBS"))
    }

    @Test func firstSignConditionCallsOnARegularPattern() {
        var s = LaborSettings()
        s.conditions = [.previousCesarean]
        let a = analysis(series(every: Array(repeating: 420, count: 10), length: 50), settings: s)
        #expect(a.advice.headline == "Time to call the hospital.")
    }

    @Test func gbsMakesWatersUrgentAndPushingDialsEmergency() {
        var s = LaborSettings()
        s.conditions = [.gbs]
        let waters = LaborEvent(kind: .waters, time: now.addingTimeInterval(-60), fluid: .clear)
        #expect(analysis([], events: [waters], settings: s).flags.first?.text.contains("GBS") == true)
        let push = LaborEvent(kind: .pushing, time: now.addingTimeInterval(-30))
        #expect(analysis([], events: [push]).flags.first?.isEmergency == true)
    }

    @Test func ruleNames() {
        #expect(LaborRule.fiveOneOne.name == "5-1-1")
        #expect(LaborRule.laterBaby.name == "5 min · 1:00 · 20 m")
    }

    @Test func adviceInPlainWords() {
        #expect(analysis([]).advice.headline == "Tap Start when a contraction begins.")
        #expect(analysis(series(every: [300, 300])).advice.headline == "Keep timing.")
        #expect(analysis(series(every: Array(repeating: 290, count: 14), length: 62)).advice.tone == .go)
        #expect(analysis(series(every: Array(repeating: 90, count: 6), length: 45)).advice.tone == .urgent)
        let gaps: [TimeInterval] = [900, 300, 1500, 420, 1200, 600, 700, 1200, 300, 1500]
        #expect(analysis(series(every: gaps, length: 35, strength: .mild)).advice.headline.hasPrefix("Probably practice"))
    }

    private func stage(_ stage: LaborStage, _ minutesAgo: Double) -> LaborEvent {
        LaborEvent(kind: .stage, time: now.addingTimeInterval(-minutesAgo * 60), stage: stage)
    }

    @Test func stageIsTheLatestPick() {
        #expect(analysis([]).stage == .before)
        #expect(analysis([], events: [stage(.early, 90), stage(.active, 10)]).stage == .active)
        #expect(analysis([], events: [stage(.active, -5)]).stage == .before)
    }

    @Test func suggestsTheNextStageFromTiming() {
        let early = series(every: Array(repeating: 420, count: 10), length: 50)
        #expect(analysis(early).suggestedStage == .early)
        #expect(analysis(early, events: [stage(.early, 80)]).suggestedStage == nil)
        let met = series(every: Array(repeating: 290, count: 14), length: 62)
        #expect(analysis(met, events: [stage(.early, 80)]).suggestedStage == .active)
        #expect(analysis(met, events: [stage(.active, 5)]).suggestedStage == nil)
        let gaps: [TimeInterval] = [900, 300, 1500, 420, 1200, 600, 700, 1200, 300, 1500]
        #expect(analysis(series(every: gaps, length: 35, strength: .mild)).suggestedStage == nil)
    }

    @Test func noCallBannersAtTheHospital() {
        let often = series(every: Array(repeating: 90, count: 6), length: 45)
        #expect(!analysis(often).flags.isEmpty)
        #expect(analysis(often, events: [stage(.hospital, 30)]).flags.isEmpty)
    }

    @Test func birthCountsLaborFromTheFirstEarlyPick() throws {
        let contractions = series(every: Array(repeating: 300, count: 20), length: 60, endingAt: now.addingTimeInterval(-600))
        let a = analysis(contractions, events: [stage(.early, 300), stage(.hospital, 60), stage(.born, 5)])
        let birth = try #require(a.birth)
        #expect(birth.time == now.addingTimeInterval(-300))
        #expect(birth.laborStart == now.addingTimeInterval(-300 * 60))
        #expect(birth.contractions == 21)
    }

    @Test func migratesTheSingleLaborIntoAProfileOnce() throws {
        let defaults = try #require(UserDefaults(suiteName: "labor-migration-test"))
        defaults.removePersistentDomain(forName: "labor-migration-test")
        let contractions = series(every: [300, 300])
        var settings = LaborSettings()
        settings.phone = "555"
        defaults.set(try JSONEncoder().encode(contractions), forKey: LaborStore.oldKeys.contractions)
        defaults.set(try JSONEncoder().encode(settings), forKey: LaborStore.oldKeys.settings)

        LaborStore.migrate(defaults)
        LaborStore.migrate(defaults)

        let profiles: [LaborProfile] = try #require(defaults.decoded(LaborStore.profilesKey))
        #expect(profiles.count == 1)
        #expect(profiles[0].contractions == contractions)
        #expect(profiles[0].settings.phone == "555")
        #expect(profiles[0].created == contractions[0].start)
        #expect(defaults.data(forKey: LaborStore.oldKeys.contractions) == nil)
        defaults.removePersistentDomain(forName: "labor-migration-test")
    }

    @Test func newLaborKeepsHowYouGetThere() {
        var old = LaborProfile(name: "First")
        old.settings.hospital = "St. Mary's"
        old.settings.travelMinutes = 40
        old.settings.conditions = [.gbs]
        old.settings.setupDone = true
        old.contractions = series(every: [300])
        let next = LaborProfile.next(after: old, name: "Second")
        #expect(next.settings.hospital == "St. Mary's")
        #expect(next.settings.travelMinutes == 40)
        #expect(!next.settings.firstBaby)
        #expect(next.settings.conditions.isEmpty)
        #expect(!next.settings.setupDone)
        #expect(next.contractions.isEmpty)
    }

    @Test func pregnancyWeeksTermAndDue() throws {
        var settings = LaborSettings()
        settings.dueDate = date(2026, 10, 30)
        let p = try #require(Pregnancy(settings: settings, now: now, calendar: gregorian()))
        #expect(p.weeksText == "38 weeks 2 days")
        #expect(p.term == .earlyTerm)
        #expect(p.dueText == "Due in 12 days")
        settings.dueDate = date(2026, 10, 10)
        let late = try #require(Pregnancy(settings: settings, now: now, calendar: gregorian()))
        #expect(late.term == .lateTerm)
        #expect(late.dueText == "8 days past the due date")
        settings.dueDate = date(2026, 12, 20)
        #expect(Pregnancy(settings: settings, now: now, calendar: gregorian())?.term == .preterm)
        #expect(Pregnancy(settings: LaborSettings(), now: now) == nil)
    }

    @Test func prepTicksFromSettingsAndOldProfilesDecode() throws {
        var profile = LaborProfile(name: "A")
        #expect(!profile.isDone(.phone))
        profile.settings.phone = "555"
        profile.settings.setupDone = true
        #expect(profile.isDone(.phone) && profile.isDone(.plan))
        #expect(!PrepItem.items(firstBaby: true).contains(.siblings))
        let old = #"[{"id":"\#(UUID().uuidString)","name":"Old","created":0,"settings":{},"contractions":[],"events":[]}]"#
        let decoded = try JSONDecoder().decode([LaborProfile].self, from: Data(old.utf8))
        #expect(decoded.first?.name == "Old")
        #expect(decoded.first?.prep.isEmpty == true)
    }

    @Test func summaryOfAnEmptyEpisodeSkipsTheStats() {
        let waters = LaborEvent(kind: .waters, time: now.addingTimeInterval(-3600))
        let old = LaborEvent(kind: .show, time: now.addingTimeInterval(-30 * 3600))
        let text = analysis([], events: [waters, old]).summary()
        #expect(!text.contains("Last hour"))
        #expect(!text.contains("not met"))
        #expect(text.contains("Waters broke"))
        #expect(!text.contains("Show"))
        let timed = analysis(series(every: Array(repeating: 290, count: 14), length: 62)).summary()
        #expect(timed.contains("15 contractions"))
        #expect(timed.contains("5-1-1: met"))
    }

    @Test func laterBabyRuleReadsATwentyMinuteWindow() {
        var s = LaborSettings()
        s.firstBaby = false
        let a = analysis(series(every: Array(repeating: 290, count: 5), length: 62), settings: s)
        #expect(a.ruleCheck.isMet)
        #expect(a.ruleCheck.conditions[2].value == "20 m")
        #expect(a.ruleCheck.conditions.map(\.title) == ["Apart", "Each lasts", "Timed for"])
    }

    @Test func ruleHintsSayWhyItIsNotMet() {
        let few = analysis(series(every: [290, 290]))
        #expect(few.ruleCheck.conditions[0].hint?.hasPrefix("Needs 4 gaps") == true)
    }

    @Test func earlyLaborAdviceQuotesTheRealGap() {
        var s = LaborSettings()
        s.firstBaby = false
        s.fastLastLabor = true
        let a = analysis(series(every: Array(repeating: 420, count: 8), length: 62), settings: s)
        #expect(a.pattern.pattern == .earlyLike)
        #expect(!a.ruleCheck.isMet)
        #expect(a.advice.detail.contains("about 7:00 apart"))
    }

    @Test func keepTimingCountsWhatIsLeft() {
        let a = analysis(series(every: [300, 300]))
        #expect(a.advice.detail == "2 more contractions and 9 m to tell what this is.")
    }

    @Test func activeStageAdviceNeverSaysRest() {
        let picked = LaborEvent(kind: .stage, time: now.addingTimeInterval(-60), stage: .active)
        let a = analysis(series(every: Array(repeating: 420, count: 8), length: 62), events: [picked])
        #expect(a.advice.tone == .go)
    }

    @Test func outOfRangeDueDateIsIgnored() {
        var s = LaborSettings()
        s.dueDate = now.addingTimeInterval(300 * 86_400)
        #expect(s.gestation(at: now) == nil)
        #expect(Pregnancy(settings: s, now: now) == nil)
        #expect(LaborSettings.dueRange(now: now).contains(now.addingTimeInterval(14 * 86_400)))
    }

    @Test func defaultProfileKeepsItsID() {
        #expect(LaborStore.current(in: [], id: "").id == LaborStore.current(in: [], id: "").id)
        let added = LaborStore.adding(after: LaborStore.current(in: [], id: ""), to: [])
        #expect(added.profiles.count == 2 && added.profiles.last?.id == added.next.id)
    }

    @Test func openContractionKeepsTheEpisodeAlive() {
        let start = now.addingTimeInterval(-4 * 3600)
        let a = analysis([Contraction(start: start)])
        #expect(a.open?.start == start)
        #expect(!a.episode.isEmpty)
    }

    @Test func editorRejectsOverlaps() {
        let a = Contraction(start: now, end: now.addingTimeInterval(60))
        let b = Contraction(start: now.addingTimeInterval(30), end: now.addingTimeInterval(90))
        let c = Contraction(start: now.addingTimeInterval(120), end: now.addingTimeInterval(180))
        #expect(ContractionEditor.clash(b, with: [a, b, c])?.id == a.id)
        #expect(ContractionEditor.clash(c, with: [a, b, c]) == nil)
    }

    @Test func clockAndSpanAtTheHour() {
        #expect(LaborAnalysis.clock(3599) == "59:59")
        #expect(LaborAnalysis.clock(3600) == "1 h")
        #expect(LaborAnalysis.span(3660) == "1 h 1 m")
        #expect(LaborAnalysis.count(1, "contraction") == "1 contraction")
        #expect(LaborAnalysis.count(3, "contraction") == "3 contractions")
    }

    @Test func emergencyFlagComesFirst() {
        let events = [
            LaborEvent(kind: .bleeding, time: now.addingTimeInterval(-60)),
            LaborEvent(kind: .waters, time: now.addingTimeInterval(-120)),
            LaborEvent(kind: .pushing, time: now.addingTimeInterval(-30)),
        ]
        #expect(analysis([], events: events).flags.map(\.id) == ["emergency", "waters", "bleeding"])
    }

    @Test func dialKeepsExtensionsAndDropsOtherDigits() {
        #expect(LaborView.telURL("+1 (555) 123-4567, 89#")?.absoluteString == "tel:+15551234567,89%23")
        #expect(LaborView.telURL("١٢٣") == nil)
        #expect(LaborView.telURL("") == nil)
    }

    @Test func skippedSetupIsNotDone() {
        var profile = LaborProfile(name: "A")
        profile.settings.setupSkipped = true
        #expect(!profile.isDone(.plan))
    }
}
