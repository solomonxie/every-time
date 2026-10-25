import Foundation

/// What the idle page offers: bed and wake from the picks, else the usual hours, else from now.
struct SleepPlan {
    /// Nap or Sleep after the nap block: inside the usual sleep hours it's always Sleep.
    let kind: SleepKind
    let choice: WakeChoice
    let sleepNow: SleepNow
    /// Why Nap is off right now; nil when it's allowed.
    let napBlocked: String?

    /// `pickedBed` at or before now means "now", for as long as `pickedWake` is still ahead.
    static func resolve(now: Date, kind: SleepKind, napMinutes: Int, pickedBed: Date?, pickedWake: Date?,
                        profile: JetLagProfile, nights: [PastNight], calendar: Calendar = .current) -> SleepPlan {
        let advice = NapAdvice(profile: profile, calendar: calendar)
        let lastNight = nights.first { $0.end <= now }
        let justWoke = lastNight?.isResleep(at: now) ?? false
        let slept = nights.contains { $0.end <= now && now.timeIntervalSince($0.end) < 14 * 3600 }
        let blocked = napBlocked(profile, now: now, slept: slept, calendar: calendar)
        let kind = blocked == nil ? kind : .sleep

        let usualWake = { SleepSuggestion.nextOccurrence(ofMinutes: profile.usualWake, after: $0, calendar: calendar) }
        let tonight = SleepSuggestion.nextOccurrence(ofMinutes: profile.usualBedtime, after: now, calendar: calendar)
        let inUsualHours = usualWake(now) < tonight
        let picked = pickedBed.flatMap { $0.timeIntervalSince(now) >= 60 ? $0 : pickedWake.map { $0 > now } == true ? now : nil }
        let bed = kind == .nap ? now : SleepRing.snap(picked ?? (justWoke || (inUsualHours && !slept) ? now : tonight))

        let resleep = kind == .sleep && justWoke && bed.timeIntervalSince(now) <= Double(SleepRing.step) * 30
        let shortfall = resleep ? lastNight.map { SleepTrend.need(profile) - $0.asleep } : nil
        let sleepNow = SleepNow(advice: advice, start: bed, resleepShortfall: shortfall)
        let shortest = WakeChoice(now: now, bed: bed, wake: bed, resleep: resleep).minLength
        let fits = { (wake: Date) in wake.timeIntervalSince(bed) >= shortest ? wake : nil }
        let usual = fits(SleepRing.snap(usualWake(bed)))
        let long = sleepNow.pick.flatMap { fits(SleepRing.snap($0.time)) }
        let wake = kind == .nap ? bed.addingTimeInterval(Double(napMinutes) * 60)
            : SleepRing.snap(pickedWake.flatMap { $0.timeIntervalSince(bed) >= shortest - 60 ? $0 : nil }
                ?? (resleep ? long ?? usual : usual ?? long) ?? bed.addingTimeInterval(8 * 3600))
        return SleepPlan(kind: kind, choice: WakeChoice(now: now, bed: bed, wake: wake, resleep: resleep),
                         sleepNow: sleepNow, napBlocked: blocked)
    }

    /// Within an hour of the usual bedtime, or inside the usual night before having slept.
    static func napBlocked(_ profile: JetLagProfile, now: Date, slept: Bool, calendar: Calendar = .current) -> String? {
        let minute = calendar.minutesOfDay(now)
        let (bed, wake) = (profile.usualBedtime, profile.usualWake)
        let from = (bed - 60 + 24 * 60) % (24 * 60)
        let nearBed = from <= bed ? (from..<bed).contains(minute) : (minute >= from || minute < bed)
        let inNight = bed <= wake ? (bed...wake).contains(minute) : (minute >= bed || minute <= wake)
        guard nearBed || (inNight && !slept) else { return nil }
        return "It's within an hour of, or inside, your usual sleep hours (\(bed.timeOfDayText) – \(wake.timeOfDayText)). Use Sleep instead."
    }
}
