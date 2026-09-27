import SwiftUI

/// One board: [ Board | Roadmap | Insights ].
struct BoardView: View {
    let listID: String

    var body: some View {
        Text("Board").navigationTitle("Board")
    }
}
