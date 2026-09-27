import SwiftUI

@main
struct EveryTimeWatchApp: App {
    @State private var store = WatchStore()

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environment(store)
                .task { store.activate() }
        }
    }
}
