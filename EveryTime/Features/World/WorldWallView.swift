import SwiftUI

/// Sideways World: the same scrolling timeline, using the landscape width to show many more hours.
struct WorldWallView: View {
    let rows: [TimelineRow]
    let start: Date
    let hours: Int
    @State var cursor: Date
    @State var followsNow: Bool
    @State private var position = ScrollPosition()

    var body: some View {
        SidewaysScreen(horizontalPadding: 36) {
            VStack(alignment: .leading, spacing: 6) {
                header
                ScrollView(.vertical, showsIndicators: false) {
                    TimelineGrid(rows: rows, start: start, hours: hours, cursor: cursor, position: $position,
                                 isEditing: false, snaps: !followsNow,
                                 onScroll: { if !followsNow { cursor = date(atOffset: $0) } },
                                 onDragStart: { followsNow = false },
                                 onRemove: { _ in }, onMove: { _, _ in })
                }
            }
        }
        .onAppear { scroll(to: cursor, animated: false) }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                if followsNow { cursor = .now; scroll(to: cursor, animated: false) }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            SidewaysCloseButton()
            Text(cursor.formatted(.dateTime.hour().minute()))
                .font(.clock(34))
                .contentTransition(.numericText())
            Text(cursor.formatted(.dateTime.weekday(.wide).month().day()))
                .font(.label).foregroundStyle(.secondary)
            Spacer()
            Button {
                followsNow = true
                cursor = .now
                scroll(to: cursor)
            } label: { Label("Now", systemImage: "location.fill") }
                .buttonStyle(.soft)
                .disabled(followsNow)
                .opacity(followsNow ? 0.4 : 1)
        }
        .animation(.snappy, value: cursor)
    }

    private func date(atOffset x: CGFloat) -> Date {
        start.addingTimeInterval(Double(x / TimelineGrid.cellWidth) * 3600)
    }

    private func scroll(to date: Date, animated: Bool = true) {
        let x = CGFloat(date.timeIntervalSince(start) / 3600) * TimelineGrid.cellWidth
        withAnimation(animated ? .snappy : nil) { position.scrollTo(x: x) }
    }
}
