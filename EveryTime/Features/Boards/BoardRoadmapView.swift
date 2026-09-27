import SwiftUI

/// Due dates and calendar milestones across weeks. Scrolls inside BoardView's page.
struct BoardRoadmapView: View {
    let config: BoardConfig
    let cards: [BoardCard]
    let onOpen: (BoardCard) -> Void

    var body: some View {
        Text("Roadmap")
    }
}
