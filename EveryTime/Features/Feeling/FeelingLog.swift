import SwiftUI

/// A feeling you can be in. Feelings of one kind replace each other (happy ends sad); different kinds overlay.
struct Feeling: Identifiable, Hashable {
    enum Kind: String { case mood, energy, focus, appetite, body, other }

    let id: String
    let title: String
    let symbol: String
    let tint: Color
    let kind: Kind

    /// Tags carry a prefix so a feeling never collides with a What did activity.
    var tag: String { Self.prefix + id }
    static let prefix = "feel."

    static let builtIn: [Feeling] = [
        Feeling(id: "happy", title: "Happy", symbol: "sun.max.fill", tint: .yellow, kind: .mood),
        Feeling(id: "calm", title: "Calm", symbol: "leaf.fill", tint: .mint, kind: .mood),
        Feeling(id: "sad", title: "Sad", symbol: "cloud.rain.fill", tint: .blue, kind: .mood),
        Feeling(id: "anxious", title: "Anxious", symbol: "wind", tint: .orange, kind: .mood),
        Feeling(id: "angry", title: "Angry", symbol: "flame.fill", tint: .red, kind: .mood),
        Feeling(id: "energized", title: "Energized", symbol: "bolt.fill", tint: Color(red: 0.95, green: 0.62, blue: 0.1), kind: .energy),
        Feeling(id: "tired", title: "Tired", symbol: "battery.25percent", tint: .gray, kind: .energy),
        Feeling(id: "sleepy", title: "Sleepy", symbol: "zzz", tint: .indigo, kind: .energy),
        Feeling(id: "focused", title: "Focused", symbol: "scope", tint: .teal, kind: .focus),
        Feeling(id: "bored", title: "Bored", symbol: "hourglass", tint: .brown, kind: .focus),
        Feeling(id: "hungry", title: "Hungry", symbol: "carrot.fill", tint: .green, kind: .appetite),
        Feeling(id: "full", title: "Full", symbol: "takeoutbag.and.cup.and.straw.fill", tint: Color(red: 0.2, green: 0.55, blue: 0.3), kind: .appetite),
        Feeling(id: "sick", title: "Sick", symbol: "cross.case.fill", tint: .pink, kind: .body),
    ]

    static func of(tag: String) -> Feeling? {
        guard tag.hasPrefix(prefix) else { return nil }
        return all.first { $0.tag == tag }
    }

    static var all: [Feeling] { builtIn + custom.map(\.feeling) }

    static let kinds: [(id: String, title: String)] = [
        ("mood", "Mood"), ("energy", "Energy"), ("focus", "Focus"), ("appetite", "Appetite"), ("body", "Body"), ("other", "On its own"),
    ]

    /// Your own feelings; the page keeps this in step with what's stored.
    nonisolated(unsafe) static var custom: [CustomFeeling] = AppData.defaults.decoded(CustomFeeling.key) ?? []

    var activity: Activity { Activity(id: tag, title: title, symbol: symbol, tint: tint) }
}

/// A feeling you added: its look and which kind it belongs to.
struct CustomFeeling: Codable, Equatable, Identifiable {
    static let key = "timers.feelingTags"

    var name: String
    var style = TagStyle()
    var kind = "other"

    var id: String { name }
    var feeling: Feeling {
        Feeling(id: name, title: name, symbol: style.symbol, tint: style.tint, kind: Feeling.Kind(rawValue: kind) ?? .other)
    }
}

/// One stretch of a feeling; open until ended.
struct FeelingMark: Identifiable, Codable, Hashable {
    var id = UUID()
    var feeling: String
    var start: Date
    var end: Date?
}

/// Feelings as stretches that may overlap, and the rules for starting and ending them.
struct FeelingLog {
    static let key = "timers.feelings"
    /// A feeling nobody ended fades out after this.
    static let maxOpen: TimeInterval = 12 * 3600

    var marks: [FeelingMark]

    /// Oldest first; open ones run to now, for at most `maxOpen`.
    func spans(at now: Date) -> [ActivitySpan] {
        marks.filter { $0.start <= now }.sorted { $0.start < $1.start }.map { mark in
            let cap = mark.start.addingTimeInterval(Self.maxOpen)
            let end = mark.end.map { min($0, now) } ?? min(now, cap)
            return ActivitySpan(id: mark.id, tag: Feeling.prefix + mark.feeling, start: mark.start, end: max(mark.start, end),
                                isOpen: mark.end == nil && now < cap)
        }
    }

    /// Still going on at `now`.
    func active(at now: Date) -> [FeelingMark] {
        marks.filter { $0.start <= now && ($0.end ?? $0.start.addingTimeInterval(Self.maxOpen)) > now && $0.end.map { $0 > now } ?? true }
    }

    /// Starts `feeling` at `time`, ending any open feeling of the same kind then.
    func starting(_ feeling: Feeling, at time: Date) -> FeelingLog {
        var marks = marks.map { mark -> FeelingMark in
            guard mark.end == nil, mark.start < time, feeling.kind != .other,
                  Feeling.all.first(where: { $0.id == mark.feeling })?.kind == feeling.kind
            else { return mark }
            var ended = mark
            ended.end = time
            return ended
        }
        marks.append(FeelingMark(feeling: feeling.id, start: time))
        return FeelingLog(marks: marks)
    }

    func ending(_ id: UUID, at time: Date) -> FeelingLog {
        FeelingLog(marks: marks.map { mark in
            guard mark.id == id, mark.end == nil else { return mark }
            var ended = mark
            ended.end = max(mark.start, time)
            return ended
        })
    }
}
