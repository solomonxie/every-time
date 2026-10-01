import SwiftUI

/// Sample data for screenshots, in its own store; real data, notifications and backups are left alone.
struct DemoSection: View {
    @AppStorage(AppData.demoKey, store: .standard) private var demoOn = false
    @State private var resetCount = 0

    var body: some View {
        Section {
            Toggle(isOn: Binding(get: { demoOn }, set: { AppData.setDemo($0) })) {
                Label("Demo mode", systemImage: "sparkles.rectangle.stack")
            }
            .frame(minHeight: 44)
            if AppData.isDemo {
                Button {
                    DemoSeed.seed()
                    resetCount += 1
                } label: {
                    Label("Reset demo data", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .sensoryFeedback(.success, trigger: resetCount)
            }
        } header: {
            SectionLabel("Demo").textCase(nil)
        } footer: {
            Text("Sample cities, sleep, naps, trips and timers in a separate store, for screenshots. Your own data, notifications, widgets and backups aren't touched; turn off to go back.")
        }
        .listRowBackground(Theme.cardFill)
    }
}
