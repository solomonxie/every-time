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
            CalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }
            ToolsView()
                .tabItem { Label("Tools", systemImage: "wrench.and.screwdriver") }
        }
    }
}

#Preview {
    ContentView()
}
