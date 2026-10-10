import Foundation

/// When to stop coffee before bed.
enum Caffeine {
    /// Caffeine's half-life is ~5 h; a 2023 meta-analysis puts a cup of coffee's cutoff at ~8.8 h before bed.
    static let hoursBeforeBed = 9.0

    static func cutoff(bed: Date) -> Date { bed.addingTimeInterval(-hoursBeforeBed * 3600) }
}
