import Foundation
import Testing
@testable import EveryTime

private func json(_ text: String) -> Data { Data(text.utf8) }

private func withSuite(_ body: (UserDefaults) throws -> Void) throws {
    let suite = "EveryTimeTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    try body(defaults)
}

struct StoreCodecTests {
    @Test func undecodableDataIsNotOverwritten() throws {
        try withSuite { defaults in
            let junk = json(#"[{"time":"not a date"}]"#)
            defaults.set(junk, forKey: "timers.activityLog")
            let stored = Stored<[ActivityMark]>(wrappedValue: [], "timers.activityLog", store: defaults)
            #expect(stored.wrappedValue.isEmpty)

            stored.wrappedValue = [ActivityMark(time: date(2026, 10, 1, 9))]
            #expect(defaults.data(forKey: "timers.activityLog.corrupt") == junk)
            #expect(stored.wrappedValue.count == 1)

            defaults.set(json("[1]"), forKey: "timers.activityLog")
            stored.wrappedValue = []
            #expect(defaults.data(forKey: "timers.activityLog.corrupt") == junk)
            #expect(defaults.data(forKey: "timers.activityLog") == json("[1]"))
        }
    }

    @Test func encodeFailureKeepsData() throws {
        try withSuite { defaults in
            defaults.encode([1.5], "tools.ratios")
            defaults.encode([Double.nan], "tools.ratios")
            let kept: [Double]? = defaults.decoded("tools.ratios")
            #expect(kept == [1.5])

            let stored = Stored<[Double]>(wrappedValue: [], "tools.ratios", store: defaults)
            stored.wrappedValue = [.infinity]
            #expect(stored.wrappedValue == [1.5])
        }
    }

    @Test func helpersRoundTripAndClear() throws {
        try withSuite { defaults in
            let nap = ActiveNap(start: date(2026, 10, 1, 14), minutes: 20)
            defaults.encode(nap as ActiveNap?, NapKey.active)
            let saved: ActiveNap? = defaults.decoded(NapKey.active)
            #expect(saved == nap)
            defaults.encode(nil as ActiveNap?, NapKey.active)
            let cleared: ActiveNap? = defaults.decoded(NapKey.active)
            #expect(cleared == nil)
            defaults.encode(nap as ActiveNap?, NapKey.active)
            #expect(defaults.object(forKey: StoreCodec.corruptKey(NapKey.active)) == nil)
        }
    }

    @Test func corruptCopiesStayOutOfBackups() throws {
        try withSuite { defaults in
            defaults.set(json("[1]"), forKey: "timers.workLog")
            defaults.set(json(#"[{"x":1}]"#), forKey: "timers.workLog.corrupt")
            #expect(!BackupSnapshot.isBackedUp("timers.workLog.corrupt"))
            #expect(BackupSnapshot.current(in: defaults).entries.keys.sorted() == ["timers.workLog"])

            let incoming = try BackupSnapshot(json: json(#"{"version":1,"entries":{"timers.workLog":[],"sleep.naps.corrupt":[]}}"#))
            #expect(incoming.entries.keys.sorted() == ["timers.workLog"])
            incoming.apply(to: defaults)
            #expect(defaults.data(forKey: "timers.workLog.corrupt") == json(#"[{"x":1}]"#))
        }
    }
}

/// JSON as earlier versions wrote it must keep decoding. Dates are seconds since 2001, as `JSONEncoder` writes them.
struct StoredModelFixtureTests {
    private func decode<T: Decodable>(_ type: T.Type, _ text: String) throws -> T {
        try JSONDecoder().decode(type, from: json(text))
    }

    private let id = "E621E1F8-C36C-495A-93FC-0C247A3E6E5F"

    @Test func activityMark() throws {
        let mark = try decode(ActivityMark.self, #"{"id":"\#(id)","time":800000000}"#)
        #expect(mark.tag == nil && mark.alarm == nil && !mark.isDaily)
        let full = try decode(ActivityMark.self, #"{"id":"\#(id)","time":800000000,"tag":"work","alarm":true,"repeats":"daily"}"#)
        #expect(full.tag == "work" && full.alarm == true && full.isDaily)
    }

    @Test func nap() throws {
        let nap = try decode(Nap.self, #"{"id":"\#(id)","start":800000000,"end":800001200}"#)
        #expect(nap.minutes == 20 && nap.night == nil && nap.natural == nil)
        let night = try decode(Nap.self, #"{"id":"\#(id)","start":800000000,"end":800028800,"night":"good","energy":4,"natural":true}"#)
        #expect(night.night == .good && night.energy == 4)
    }

    @Test func activeNap() throws {
        let nap = try decode(ActiveNap.self, #"{"start":800000000,"minutes":20}"#)
        #expect(nap.ringsAlarm && nap.resleep == nil)
    }

    @Test func countdown() throws {
        let countdown = try decode(Countdown.self, #"{"name":"Launch","target":800000000}"#)
        #expect(countdown.effect == .fireworks && countdown.sound && countdown.createdAt == countdown.target)
    }

    @Test func importantEvent() throws {
        let event = try decode(ImportantEvent.self, #"{"name":"Wedding","date":800000000}"#)
        #expect(event.type == .other && event.source == .manual && event.notify && !event.hasTime)
    }

    @Test func worldCity() throws {
        let city = try decode(WorldCity.self, #"{"name":"Tokyo","timeZoneIdentifier":"Asia/Tokyo"}"#)
        #expect(city.timeZone.identifier == "Asia/Tokyo")
    }

    @Test func singleLegTrip() throws {
        let trip = try decode(Trip.self, #"""
            {"id":"\#(id)","origin":{"name":"London","timeZoneIdentifier":"Europe/London"},
             "destination":{"name":"Tokyo","timeZoneIdentifier":"Asia/Tokyo"},
             "departure":800000000,"arrival":800050000}
            """#)
        #expect(trip.legs.count == 1 && trip.destination.name == "Tokyo" && trip.preAdjustDays == 2 && trip.notifications)
    }

    @Test func jetLagProfile() throws {
        let profile = try decode(JetLagProfile.self, #"""
            {"age":40,"sex":"female","chronotype":"late","usualBedtime":1380,"usualWake":420,
             "melatonin":false,"caffeine":true,"notifications":true}
            """#)
        #expect(profile.chronotype == .late && profile.sleepHours == 8)
    }

    @Test func sleepCycle() throws {
        let cycle = try decode(SleepCycle.self, "{}")
        #expect(cycle.minutes == SleepCycle.defaultMinutes && cycle.fallAsleepMinutes == 15)
        let manual = try decode(SleepCycle.self, #"{"manualMinutes":100}"#)
        #expect(manual.minutes == 100)
    }

    @Test func workSpan() throws {
        let span = try decode(WorkSpan.self, #"{"id":"\#(id)","kind":"work","start":800000000}"#)
        #expect(span.kind == .work && span.end == nil)
    }

    @Test func feelingMark() throws {
        let mark = try decode(FeelingMark.self, #"{"id":"\#(id)","feeling":"happy","start":800000000,"end":800003600}"#)
        #expect(mark.feeling == "happy" && mark.end != nil)
    }

    @Test func customFeelingAndTagStyle() throws {
        let feeling = try decode(CustomFeeling.self, #"{"name":"Calm","style":{"symbol":"leaf.fill","color":"green"},"kind":"other"}"#)
        #expect(feeling.style.color == "green")
    }

    @Test func timerSession() throws {
        let session = try decode(TimerSession.self, #"{"id":"\#(id)","problem":"Two Sum","difficulty":"Easy","finishedAt":800000000,"duration":900}"#)
        #expect(session.difficulty == .easy && session.duration == 900)
    }
}
