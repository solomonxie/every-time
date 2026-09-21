import Combine
import SwiftUI

struct WatchContentView: View {
    @State private var now = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 4) {
            Text(now, style: .time)
                .font(.system(.title2, design: .rounded))
            Text("Every Time")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .onReceive(timer) { now = $0 }
    }
}

#Preview {
    WatchContentView()
}
