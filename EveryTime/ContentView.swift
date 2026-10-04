import SwiftUI

/// Tab bar = the user's 1–4 pinned tools, then More.
struct ContentView: View {
    static let moreTag = "more"

    @Stored("app.tabs") private var pinned = AppTool.defaultPins.map(\.rawValue)
    @AppStorage("app.tab") private var savedTab = AppTool.defaultPins[0].rawValue
    /// Selection lives in @State; binding TabView straight to UserDefaults drops taps on iOS 18.
    @State private var tab = ""
    /// Local only, so a restored backup doesn't pin it again.
    @AppStorage("migrated.pinWhatDid") private var pinnedWhatDid = false
    @AppStorage("migrated.pinFeeling") private var pinnedFeeling = false

    private var pins: [AppTool] { AppTool.pins(from: pinned) }

    var body: some View {
        TabView(selection: $tab) {
            ForEach(pins) { tool in
                Tab(tool.tabTitle, systemImage: tool.symbol, value: tool.rawValue) { tool.tab }
            }
            Tab("More", systemImage: "ellipsis.circle", value: Self.moreTag) { MoreView() }
        }
        .onAppear {
            pinWhatDidOnce()
            pinFeelingOnce()
            tab = ScreenshotHook.tab(pins: pins) ?? sleepTab ?? savedTab
            keepSelectionValid(fallback: pins[0].rawValue)
        }
        .onChange(of: tab) { savedTab = tab }
        .onChange(of: pinned) { keepSelectionValid(fallback: Self.moreTag) }
    }

    /// Opened while asleep: straight to the night screen.
    private var sleepTab: String? {
        let active: ActiveNap? = AppData.defaults.decoded(NapKey.active)
        return active != nil && pins.contains(.sleep) ? AppTool.sleep.rawValue : nil
    }

    /// Adds What did to an existing tab bar once, if there's room.
    private func pinWhatDidOnce() {
        guard !pinnedWhatDid else { return }
        pinnedWhatDid = true
        if pins.count < AppTool.maxPins, !pins.contains(.whatDid) {
            pinned = (pins + [.whatDid]).map(\.rawValue)
        }
    }

    /// Adds Feeling to the tab bar once; a full bar gives up its last pin.
    private func pinFeelingOnce() {
        guard !pinnedFeeling else { return }
        pinnedFeeling = true
        guard !pins.contains(.feeling) else { return }
        pinned = (Array(pins.prefix(AppTool.maxPins - 1)) + [.feeling]).map(\.rawValue)
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
