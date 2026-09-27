import SwiftUI

/// Progress, burn-up, velocity, flow and per-column counts. Scrolls inside BoardView's page.
struct BoardInsightsView: View {
    let config: BoardConfig
    let cards: [BoardCard]

    var body: some View {
        Text("Insights")
    }
}
