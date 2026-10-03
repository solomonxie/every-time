import Foundation

/// Store screenshot launch arguments; only in builds with the SCREENSHOTS flag.
///   -demo YES      demo mode, freshly seeded
///   -screen <tool> open that tool (a tab, else pushed from More); `more` for More
///   -nap <minutes> a nap in progress, a third of the way in, no alarm scheduled
enum ScreenshotHook {
    #if SCREENSHOTS
    private static let launch = UserDefaults.standard
    static var screen: String? { launch.string(forKey: "screen") }

    static func apply() {
        guard launch.bool(forKey: "demo") else { return }
        launch.set(true, forKey: AppData.demoKey)
        DemoSeed.seed()
        let minutes = launch.integer(forKey: "nap")
        if minutes > 0 {
            let nap = ActiveNap(start: .now.addingTimeInterval(-Double(minutes) * 20), minutes: minutes)
            AppData.defaults.encode(nap as ActiveNap?, NapKey.active)
        }
    }
    #else
    static var screen: String? { nil }
    static func apply() {}
    #endif

    static func tab(pins: [AppTool]) -> String? {
        guard let screen else { return nil }
        if screen == ContentView.moreTag { return screen }
        guard let tool = AppTool(rawValue: screen) else { return nil }
        return pins.contains(tool) ? screen : ContentView.moreTag
    }

    static func morePath(pins: [AppTool]) -> [AppTool] {
        guard let tool = screen.flatMap(AppTool.init(rawValue:)), !pins.contains(tool) else { return [] }
        return [tool]
    }
}
