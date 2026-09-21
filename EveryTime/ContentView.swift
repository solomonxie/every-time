import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            ClocksView()
                .tabItem { Label("Clocks", systemImage: "globe") }
            TimersView()
                .tabItem { Label("Timers", systemImage: "timer") }
            SleepView()
                .tabItem { Label("Sleep", systemImage: "moon.stars") }
            MoreView()
                .tabItem { Label("More", systemImage: "ellipsis.circle") }
        }
    }
}

#Preview {
    ContentView()
}
