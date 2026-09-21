import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            ClocksView()
                .tabItem { Label("Clocks", systemImage: "globe") }
            TimersView()
                .tabItem { Label("Timers", systemImage: "timer") }
            MeetingsView()
                .tabItem { Label("Meetings", systemImage: "person.2") }
            SleepView()
                .tabItem { Label("Sleep", systemImage: "moon.stars") }
            WaitingView()
                .tabItem { Label("Waiting", systemImage: "hourglass") }
        }
    }
}

#Preview {
    ContentView()
}
