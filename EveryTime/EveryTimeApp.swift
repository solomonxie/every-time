import SwiftUI

@main
struct EveryTimeApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var timers = TimerStore()
    @AppStorage(AppData.demoKey, store: .standard) private var demoOn = false

    init() {
        if AppData.isDemo { DemoSeed.seedIfNeeded() }
        NapAlarm.register()
        SleepCycle.current.apply()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(timers)
                .timerAlarms(timers)
                .defaultAppStorage(AppData.defaults)
                .id(demoOn)
                .task { await FirstRunRestore.runIfNeeded() }
                .task { GlancePublisher.shared.activate() }
        }
        .onChange(of: scenePhase) { _, phase in
            GlancePublisher.shared.publish()
            switch phase {
            case .active:
                if AppData.isDemo { DemoSeed.seedIfNeeded() }
                Task { await AutoBackup.shared.refresh() }
                JetLagNotifications.reschedule()
                ImportantEventNotifications.reschedule()
                CountdownNotifications.reschedule()
                LunarNotifications.reschedule()
                NapAlarm.restore()
            case .background:
                LocalBackups.runIfDue()
                AutoBackup.shared.backUpInBackground()
            default:
                break
            }
        }
    }
}
