import Charts
import SwiftUI

/// Energy on waking, one bar per wake, latest on the right.
struct EnergyChart: View {
    let naps: [Nap]

    static func rated(_ naps: [Nap]) -> [Nap] {
        Array(naps.filter { $0.energy != nil }.sorted { $0.end < $1.end }.suffix(shown))
    }

    static func mean(_ naps: [Nap]) -> Double? {
        let levels = rated(naps).compactMap(\.energy)
        return levels.isEmpty ? nil : Double(levels.reduce(0, +)) / Double(levels.count)
    }

    var body: some View {
        let rated = Self.rated(naps)
        Chart(rated) { nap in
            BarMark(x: .value("Wake", nap.end, unit: .hour), y: .value("Energy", nap.energy ?? 0))
                .foregroundStyle(Self.tint(nap.energy ?? 0))
                .cornerRadius(3)
        }
        .chartYScale(domain: 0...5)
        .chartYAxis { AxisMarks(values: [1, 3, 5]) }
        .chartXAxis { AxisMarks(values: .stride(by: .day)) { _ in AxisValueLabel(format: .dateTime.weekday(.narrow)) } }
        .accessibilityLabel("Energy on waking, last \(rated.count) wakes")
    }

    static let shown = 14

    static func tint(_ level: Int) -> Color {
        switch level {
        case ...2: Theme.Tone.bad
        case 3: Theme.Tone.warn
        default: Theme.Tone.good
        }
    }
}
