import Charts
import HealthKit
import SwiftUI

/// One night of sleep: from Health (first to last asleep, sources merged) or logged here.
struct PastNight: Identifiable, Equatable {
    let start: Date
    let end: Date
    let asleep: TimeInterval
    var energy: Int? = nil
    /// The logged sleep it comes from; nil for a night read from Health.
    var source: UUID? = nil

    var id: Date { start }

    /// Logged nights, stretches with under half an hour awake between joined; Health fills the other days.
    static func merged(logged: [Nap], health: [PastNight], calendar: Calendar = .current) -> [PastNight] {
        var nights: [PastNight] = []
        for nap in logged.sorted(by: { $0.start < $1.start }) {
            if let last = nights.last, nap.start.timeIntervalSince(last.end) < 30 * 60 {
                nights[nights.count - 1] = PastNight(start: last.start, end: nap.end, asleep: last.asleep + nap.duration,
                                                     energy: nap.energy ?? last.energy, source: last.source)
            } else {
                nights.append(PastNight(start: nap.start, end: nap.end, asleep: nap.duration, energy: nap.energy, source: nap.id))
            }
        }
        let own = nights.filter { $0.asleep >= Nap.nightLength }
        let days = Set(own.map { calendar.startOfDay(for: $0.end) })
        return (own + health.filter { !days.contains(calendar.startOfDay(for: $0.end)) }).sorted { $0.end > $1.end }
    }
}

enum PastNights {
    static let key = "sleep.health.asked"
    private static let store = HKHealthStore()
    private static let type = HKCategoryType(.sleepAnalysis)
    private static let sessionGap: TimeInterval = 2 * 3600
    private static let minNight: TimeInterval = 3 * 3600

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    static func requestAccess() async -> Bool {
        (try? await store.requestAuthorization(toShare: [], read: [type])) != nil
    }

    private static func samples(days: Int, now: Date) async -> [HKCategorySample] {
        let from = now.addingTimeInterval(-Double(days + 1) * 86_400)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: type, predicate: HKQuery.predicateForSamples(withStart: from, end: now))],
            sortDescriptors: [SortDescriptor(\.startDate)])
        return (try? await descriptor.result(for: store)) ?? []
    }

    static func load(days: Int = 14, now: Date = .now) async -> [PastNight] {
        let samples = await samples(days: days, now: now)
        let asleep = samples.filter { HKCategoryValueSleepAnalysis.allAsleepValues.map(\.rawValue).contains($0.value) }
        let inBed = samples.filter { $0.value == HKCategoryValueSleepAnalysis.inBed.rawValue }
        return nights(from: merge((asleep.isEmpty ? inBed : asleep).map { ($0.startDate, $0.endDate) }))
    }

    /// Typical cycle length: median time between one REM spell's start and the next, from Watch sleep stages.
    static func cycleEstimate(days: Int = 30, now: Date = .now) async -> (minutes: Int, count: Int)? {
        let rem = await samples(days: days, now: now)
            .filter { $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue }
            .map { ($0.startDate, $0.endDate) }
        return cycleEstimate(rem: rem)
    }

    /// REM bits under 20 min apart are one spell; gaps outside 60–150 min aren't one cycle.
    static func cycleEstimate(rem: [(Date, Date)], minCount: Int = 10) -> (minutes: Int, count: Int)? {
        let spells = rem.sorted { $0.0 < $1.0 }.reduce(into: [(Date, Date)]()) { out, next in
            if let last = out.last, next.0.timeIntervalSince(last.1) < 20 * 60 {
                out[out.count - 1].1 = max(last.1, next.1)
            } else {
                out.append(next)
            }
        }
        let gaps = zip(spells, spells.dropFirst())
            .map { $1.0.timeIntervalSince($0.0) / 60 }
            .filter { (60...150).contains($0) }
            .sorted()
        guard gaps.count >= minCount else { return nil }
        return (Int(gaps[gaps.count / 2].rounded()), gaps.count)
    }

    /// Overlapping intervals (Watch + iPhone) joined so no minute counts twice.
    static func merge(_ intervals: [(Date, Date)]) -> [(Date, Date)] {
        intervals.sorted { $0.0 < $1.0 }.reduce(into: []) { out, next in
            if let last = out.last, next.0 <= last.1 {
                out[out.count - 1].1 = max(last.1, next.1)
            } else {
                out.append(next)
            }
        }
    }

    /// Sessions split by 2 h awake; the longest per wake-up day is that night, naps dropped.
    static func nights(from merged: [(Date, Date)], calendar: Calendar = .current) -> [PastNight] {
        var sessions: [[(Date, Date)]] = []
        for interval in merged {
            if let last = sessions.last?.last, interval.0.timeIntervalSince(last.1) < sessionGap {
                sessions[sessions.count - 1].append(interval)
            } else {
                sessions.append([interval])
            }
        }
        let all = sessions.compactMap { parts -> PastNight? in
            guard let first = parts.first, let last = parts.last else { return nil }
            let asleep = parts.reduce(0) { $0 + $1.1.timeIntervalSince($1.0) }
            return asleep >= minNight ? PastNight(start: first.0, end: last.1, asleep: asleep) : nil
        }
        return Dictionary(grouping: all) { calendar.startOfDay(for: $0.end) }
            .values.compactMap { $0.max { $0.asleep < $1.asleep } }
            .sorted { $0.end > $1.end }
    }
}

/// Score per night, latest on the right.
struct ScoreChart: View {
    let nights: [PastNight]
    let usualHours: Double

    var body: some View {
        Chart(nights.prefix(14).reversed()) { night in
            let score = SleepScore.score(asleep: night.asleep, usualHours: usualHours, energy: night.energy)
            BarMark(x: .value("Night", night.end, unit: .day), y: .value("Score", score))
                .foregroundStyle(SleepScore.level(score).tint)
                .cornerRadius(3)
        }
        .chartYScale(domain: 0...100)
        .chartYAxis { AxisMarks(values: [0, 50, 100]) }
        .chartXAxis { AxisMarks(values: .stride(by: .day)) { _ in AxisValueLabel(format: .dateTime.weekday(.narrow)) } }
        .frame(height: 90)
        .accessibilityLabel("Sleep score, last \(min(14, nights.count)) nights")
    }
}

struct PastNightRow: View {
    let night: PastNight
    let usualHours: Double

    var body: some View {
        let fit = SleepSuggestion.fit(minutesInBed: Int((night.end.timeIntervalSince(night.start) + SleepSuggestion.fallAsleepTime) / 60))
        let score = SleepScore.score(asleep: night.asleep, usualHours: usualHours, energy: night.energy)
        SleepHistoryRow(
            date: night.end,
            detail: "\(SleepNow.clock(night.start)) – \(SleepNow.clock(night.end)) · \(fit.cycles) \(fit.cycles == 1 ? "cycle" : "cycles")",
            energy: night.energy,
            duration: NapAdvice.hours((night.asleep / 60).rounded() / 60)
        ) {
            Text("\(score)")
                .font(.clock(18, weight: .semibold))
                .foregroundStyle(SleepScore.level(score).tint)
        }
    }
}
