import SwiftUI

/// Tab bar = the user's 1–4 pinned tools, then More.
struct ContentView: View {
    static let moreTag = "more"

    @Stored("app.tabs") private var pinned = AppTool.defaultPins.map(\.rawValue)
    @AppStorage("app.tab") private var savedTab = AppTool.defaultPins[0].rawValue
    /// Selection lives in @State; binding TabView straight to UserDefaults drops taps on iOS 18.
    @State private var tab = ""

    private var pins: [AppTool] { AppTool.pins(from: pinned) }

    var body: some View {
        TabView(selection: $tab) {
            ForEach(pins) { tool in
                Tab(tool.tabTitle, systemImage: tool.symbol, value: tool.rawValue) { tool.tab }
            }
            Tab("More", systemImage: "ellipsis.circle", value: Self.moreTag) { MoreView() }
        }
        .onAppear {
            tab = savedTab
            keepSelectionValid(fallback: pins[0].rawValue)
        }
        .onChange(of: tab) { savedTab = tab }
        .onChange(of: pinned) { keepSelectionValid(fallback: Self.moreTag) }
    }

    /// Unpinning the current tab lands on More, where the change was made.
    private func keepSelectionValid(fallback: String) {
        if tab != Self.moreTag, !pins.contains(where: { $0.rawValue == tab }) {
            tab = fallback
        }
    }
}

#Preview {
    ContentView()
        .environment(TimerStore())
}
