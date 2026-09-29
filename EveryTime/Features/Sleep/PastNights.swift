import HealthKit
import SwiftUI

/// One night of sleep read from Health: first to last asleep, with overlapping sources merged.
struct PastNight: Identifiable, Equatable {
    let start: Date
    let end: Date
    let asleep: TimeInterval

    var id: Date { start }
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

    static func load(days: Int = 14, now: Date = .now) async -> [PastNight] {
        let from = now.addingTimeInterval(-Double(days + 1) * 86_400)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: type, predicate: HKQuery.predicateForSamples(withStart: from, end: now))],
            sortDescriptors: [SortDescriptor(\.startDate)])
        guard let samples = try? await descriptor.result(for: store) else { return [] }
        let asleep = samples.filter { HKCategoryValueSleepAnalysis.allAsleepValues.map(\.rawValue).contains($0.value) }
        let inBed = samples.filter { $0.value == HKCategoryValueSleepAnalysis.inBed.rawValue }
        return nights(from: merge((asleep.isEmpty ? inBed : asleep).map { ($0.startDate, $0.endDate) }))
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

/// Recent nights from the Health app, once the user lets us read sleep.
struct PastNightsSection: View {
    @AppStorage(PastNights.key) private var asked = false
    @State private var nights: [PastNight] = []
    @State private var loaded = false

    var body: some View {
        if PastNights.isAvailable {
            Section {
                if !asked {
                    Button {
                        Task {
                            asked = await PastNights.requestAccess()
                            await reload()
                        }
                    } label: {
                        Label("Show past nights from Health", systemImage: "heart.text.square")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.borderless)
                    .napRow()
                } else if loaded && nights.isEmpty {
                    Text("No sleep in Health for the last two weeks. Check Settings › Health › Data Access › Every Time.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .napRow()
                } else {
                    if nights.count >= 3 { average.napRow() }
                    ForEach(nights) { PastNightRow(night: $0).napRow() }
                }
            } header: {
                SectionLabel(title: "Past nights") {
                    InfoButton(label: "About past nights", text: Self.info)
                }
                .textCase(nil)
            }
            .task { await reload() }
        }
    }

    private var average: some View {
        let mean = nights.map(\.asleep).reduce(0, +) / Double(nights.count)
        return HStack {
            Text("Average asleep").font(.subheadline)
            Spacer()
            Text(NapAdvice.hours((mean / 60).rounded() / 60))
                .font(.label).monospacedDigit().foregroundStyle(.secondary)
        }
    }

    private func reload() async {
        guard asked else { return }
        nights = await PastNights.load()
        loaded = true
    }

    private static let info = "Last two weeks of sleep from the Health app, as recorded by your Watch, iPhone or another sleep app. Naps are left out. Nothing leaves your phone."
}

struct PastNightRow: View {
    let night: PastNight

    var body: some View {
        let fit = SleepSuggestion.fit(minutesInBed: Int((night.end.timeIntervalSince(night.start) + SleepSuggestion.fallAsleepTime) / 60))
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(night.end, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                    .font(.system(.body, design: .rounded))
                Text("\(SleepNow.clock(night.start)) – \(SleepNow.clock(night.end)) · \(fit.cycles) \(fit.cycles == 1 ? "cycle" : "cycles")")
                    .font(.label)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(NapAdvice.hours((night.asleep / 60).rounded() / 60))
                .font(.clock(20, weight: .regular))
        }
        .accessibilityElement(children: .combine)
    }
}
