import SwiftUI

struct CalendarView: View {
    private let rows = [
        "Lunar calendar alerts (birthdays & holidays)",
        "On this day (past years' events)",
        "How long since…",
    ]

    var body: some View {
        NavigationStack {
            List(rows, id: \.self) { row in
                NavigationLink(row) {
                    Text(row)
                        .foregroundStyle(.secondary)
                        .navigationTitle(row)
                }
            }
            .navigationTitle("Calendar")
        }
    }
}

#Preview {
    CalendarView()
}
