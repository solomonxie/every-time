import Foundation

/// A user countdown to a future date/time; stored under "timers.countdowns" (backed up).
struct Countdown: Identifiable, Codable, Hashable {
    enum Effect: String, Codable, CaseIterable, Identifiable {
        case fireworks, confetti
        var id: String { rawValue }
        var title: String { rawValue.capitalized }
    }

    var id = UUID()
    var name: String
    var target: Date
    var vibrate = true
    var sound = true
    var notification = true
    var animation = true
    var effect: Effect = .fireworks
    var createdAt = Date()

    static let storageKey = "timers.countdowns"

    init(id: UUID = UUID(), name: String, target: Date, vibrate: Bool = true, sound: Bool = true,
         notification: Bool = true, animation: Bool = true, effect: Effect = .fireworks, createdAt: Date = Date()) {
        (self.id, self.name, self.target, self.vibrate, self.sound) = (id, name, target, vibrate, sound)
        (self.notification, self.animation, self.effect, self.createdAt) = (notification, animation, effect, createdAt)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        target = try c.decode(Date.self, forKey: .target)
        vibrate = try c.decodeIfPresent(Bool.self, forKey: .vibrate) ?? true
        sound = try c.decodeIfPresent(Bool.self, forKey: .sound) ?? true
        notification = try c.decodeIfPresent(Bool.self, forKey: .notification) ?? true
        animation = try c.decodeIfPresent(Bool.self, forKey: .animation) ?? true
        effect = (try? c.decodeIfPresent(Effect.self, forKey: .effect)) ?? .fireworks
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? target
    }

    func remaining(at now: Date) -> TimeInterval { target.timeIntervalSince(now) }
    func isFinished(at now: Date) -> Bool { target <= now }

    /// createdAt → target, 0…1.
    func progress(at now: Date) -> Double {
        let total = target.timeIntervalSince(createdAt)
        guard total > 0 else { return 1 }
        return min(max(now.timeIntervalSince(createdAt) / total, 0), 1)
    }
}
