import SwiftUI

@main
struct EveryTimeApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task { await FirstRunRestore.runIfNeeded() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                Task { await AutoBackup.shared.refresh() }
            case .background:
                LocalBackups.runIfDue()
                AutoBackup.shared.backUpInBackground()
            default:
                break
            }
        }
    }
}
