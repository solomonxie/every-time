import SwiftUI

@main
struct EveryTimeApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var timers = TimerStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(timers)
                .timerAlarms(timers)
                .task { await FirstRunRestore.runIfNeeded() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                Task { await AutoBackup.shared.refresh() }
                JetLagNotifications.reschedule()
                ImportantEventNotifications.reschedule()
                CountdownNotifications.reschedule()
            case .background:
                LocalBackups.runIfDue()
                AutoBackup.shared.backUpInBackground()
            default:
                break
            }
        }
    }
}
