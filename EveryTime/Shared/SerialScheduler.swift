import Foundation

/// Runs async jobs one after another. Each job holds a token that goes stale once a later job is queued
/// or `invalidate()` runs; check it after every await and undo what a stale job just made.
@MainActor
final class SerialScheduler {
    struct Token: Equatable { fileprivate let generation: Int }

    private var generation = 0
    private var tail: Task<Void, Never>?

    func begin() -> Token {
        generation += 1
        return Token(generation: generation)
    }

    func invalidate() { generation += 1 }

    func isCurrent(_ token: Token) -> Bool { token.generation == generation }

    func enqueue(_ job: @escaping @MainActor (Token) async -> Void) {
        let token = begin()
        let previous = tail
        tail = Task {
            await previous?.value
            guard isCurrent(token) else { return }
            await job(token)
        }
    }
}
