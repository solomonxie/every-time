import SwiftUI

struct ContentView: View {
    @AppStorage("tab") private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            WorldView()
                .tabItem { Label("World", systemImage: "globe") }
                .tag(0)
            SleepView()
                .tabItem { Label("Sleep", systemImage: "moon.stars") }
                .tag(1)
            NavigationStack { LunarCalendarView() }
                .tabItem { Label("Lunar", systemImage: "calendar") }
                .tag(2)
            MoreView()
                .tabItem { Label("More", systemImage: "ellipsis.circle") }
                .tag(3)
        }
    }
}

#Preview {
    ContentView()
}
