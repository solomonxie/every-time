import Foundation
import Testing
@testable import EveryTime

@MainActor
struct NotificationBudgetTests {
    typealias Budget = NotificationBudget
    let now = date(2026, 10, 1, 8)

    private func requests(_ feature: Budget.Feature, _ count: Int, from minutes: Int) -> [Budget.Request] {
        (0..<count).map {
            Budget.Request(id: "\(feature.prefix)\($0)", feature: feature, fire: now.addingTimeInterval(Double(minutes + $0) * 60), title: "")
        }
    }

    @Test func allocationKeepsReservesAndMinimums() {
        let wanted = requests(.nap, 9, from: 600) + requests(.windDown, 1, from: 700) + requests(.timer, 2, from: 800)
            + requests(.jetLag, 40, from: 1) + requests(.event, 14, from: 2000)
            + requests(.countdown, 10, from: 3000) + requests(.lunar, 4, from: 4000)
        #expect(wanted.count == 80)
        let kept = Budget.allocate(wanted)
        #expect(kept.count == Budget.systemCap)
        #expect(Set(kept.map(\.id)).count == kept.count)
        for feature in Budget.Feature.allCases {
            let asked = wanted.filter { $0.feature == feature }
            let got = kept.filter { $0.feature == feature }
            if feature.reserve > 0 { #expect(got.count == asked.count) }
            #expect(got.count >= min(feature.minimum, asked.count))
            #expect(got.map(\.fire) == asked.map(\.fire).sorted().prefix(got.count).map { $0 })
        }
        #expect(kept.filter { $0.feature == .jetLag }.count == 40)
    }

    @Test func reservedSlotsStayFree() {
        let kept = Budget.allocate(requests(.jetLag, 80, from: 1))
        let reserved = Budget.Feature.allCases.map(\.reserve).reduce(0, +)
        #expect(kept.count == Budget.systemCap - reserved)
        #expect(Budget.allocate(requests(.timer, 5, from: 1)).count == Budget.Feature.timer.reserve)
    }

    @Test func diffReplacesChangedAndRemovesStale() {
        let same = Budget.Request(id: "countdown.a", feature: .countdown, fire: now.addingTimeInterval(3600), title: "A")
        var moved = Budget.Request(id: "countdown.b", feature: .countdown, fire: now.addingTimeInterval(3600), title: "B")
        let pending = [
            Budget.Pending(id: same.id, fingerprint: same.fingerprint),
            Budget.Pending(id: moved.id, fingerprint: moved.fingerprint),
            Budget.Pending(id: "lunar.gone", fingerprint: "x", fire: now.addingTimeInterval(3600)),
            Budget.Pending(id: "lunar.firing", fingerprint: "x", fire: now.addingTimeInterval(1)),
            Budget.Pending(id: "nap.alarm.0"),
        ]
        moved = Budget.Request(id: moved.id, feature: .countdown, fire: now.addingTimeInterval(7200), title: "B")
        let change = Budget.diff(pending: pending, wanted: [same, moved], now: now)
        #expect(change.remove == ["lunar.gone"])
        #expect(change.add == [moved])
    }
}
