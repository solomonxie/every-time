import SwiftUI

/// Placeholder for a tool whose code exists but isn't ready to use.
struct ComingSoonView: View {
    let tool: AppTool

    var body: some View {
        ContentUnavailableView(tool.title, systemImage: tool.symbol, description: Text("Coming soon"))
            .navigationTitle(tool.title)
    }
}
