import Foundation

struct SleepSuggestion: Identifiable {
    let id = UUID()
    let bedtime: String
    let cycles: Int
}
