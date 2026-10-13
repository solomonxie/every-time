import Foundation

/// When to stop eating before bed.
enum LastMeal {
    /// Eating within ~3 h of bed is tied to more night waking and reflux; a late dinner raises overnight glucose and cortisol.
    static let hoursBeforeBed = 3.0

    static func cutoff(bed: Date) -> Date { bed.addingTimeInterval(-hoursBeforeBed * 3600) }
}
