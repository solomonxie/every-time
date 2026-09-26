import SwiftUI

struct WorldView: View {
    @Stored("world.cities") private var cities: [WorldCity] = [
        WorldCity(timeZoneIdentifier: "America/New_York"),
        WorldCity(timeZoneIdentifier: "Europe/London"),
        WorldCity(timeZoneIdentifier: "Asia/Singapore"),
    ]
    @State private var start = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: .now))!
    @State private var cursor = Date.now
    @State private var position = ScrollPosition()
    @Stored("world.localIndex") private var localIndex = 0
    @State private var showingPicker = false
    @State private var isEditing = false

    private let hours = 24 * 8

    private var rows: [TimelineRow] {
        var rows = cities.map { TimelineRow(city: $0, isLocal: false) }
        rows.insert(TimelineRow(city: .local, isLocal: true), at: min(max(localIndex, 0), rows.count))
        return rows
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    TimelineGrid(rows: rows, start: start, hours: hours, cursor: cursor, position: $position,
                                 isEditing: isEditing,
                                 onScroll: { cursor = date(atOffset: $0) },
                                 onRemove: { city in cities.removeAll { $0 == city } },
                                 onMove: move)
                    if cities.isEmpty {
                        Text("Tap + to add a city to compare").foregroundStyle(.secondary).padding(.horizontal)
                    }
                    overlapSection
                }
                .padding(.vertical)
            }
            .navigationTitle("World")
            .safeAreaInset(edge: .bottom) { bottomBar }
            .sheet(isPresented: $showingPicker) {
                CityPickerView(excluded: Set(cities.map(\.id) + [WorldCity.local.id])) { cities.append($0) }
            }
            .onAppear { scroll(to: .now, animated: false) }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button("Now", systemImage: "location.fill") { scroll(to: .now) }
                .buttonStyle(.bordered)
            Spacer()
            Button(isEditing ? "Done" : "Edit") { withAnimation { isEditing.toggle() } }
                .buttonStyle(.bordered)
            Button("Add City", systemImage: "plus") { showingPicker = true }
                .buttonStyle(.borderedProminent)
        }
        .controlSize(.large)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func move(_ id: String, onto targetID: String) {
        var ids = rows.map(\.id)
        guard let from = ids.firstIndex(of: id), let to = ids.firstIndex(of: targetID) else { return }
        ids.move(fromOffsets: [from], toOffset: to > from ? to + 1 : to)
        let localID = WorldCity.local.id
        localIndex = ids.firstIndex(of: localID) ?? 0
        cities = ids.filter { $0 != localID }.compactMap { id in cities.first { $0.id == id } }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(cursor.formatted(.dateTime.weekday(.wide).month().day()))
                .font(.headline)
            Spacer()
            Text(relativeLabel).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    private var relativeLabel: String {
        let minutes = Int((cursor.timeIntervalSinceNow / 60 / 15).rounded()) * 15
        guard minutes != 0 else { return "Now" }
        let h = abs(minutes) / 60, m = abs(minutes) % 60
        let span = [h > 0 ? "\(h)h" : nil, m > 0 ? "\(m)m" : nil].compactMap { $0 }.joined(separator: " ")
        return minutes > 0 ? "in \(span)" : "\(span) ago"
    }

    private var overlapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WORK HOURS OVERLAP").font(.footnote).foregroundStyle(.secondary)
            let ranges = overlapRanges
            if ranges.isEmpty {
                Label("No shared 8 AM – 6 PM window this day", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            } else {
                ForEach(ranges, id: \.lowerBound) { range in
                    Button { scroll(to: range.lowerBound) } label: {
                        HStack {
                            Text(range.formatted(.interval.hour().minute()))
                            Spacer()
                            Image(systemName: "arrow.right.circle")
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    /// Hour blocks of the cursor's local day where every row is inside work hours.
    private var overlapRanges: [Range<Date>] {
        let dayStart = Calendar.current.startOfDay(for: cursor)
        let instants = (0..<24).map { dayStart.addingTimeInterval(Double($0) * 3600) }
        var ranges: [Range<Date>] = []
        for instant in instants where rows.allSatisfy({ HourShade(hour: $0.calendar.component(.hour, from: instant)) == .work }) {
            let end = instant.addingTimeInterval(3600)
            if let last = ranges.last, last.upperBound == instant {
                ranges[ranges.count - 1] = last.lowerBound..<end
            } else {
                ranges.append(instant..<end)
            }
        }
        return ranges
    }

    private func date(atOffset x: CGFloat) -> Date {
        start.addingTimeInterval(Double(x / TimelineGrid.cellWidth) * 3600)
    }

    private func scroll(to date: Date, animated: Bool = true) {
        let x = CGFloat(date.timeIntervalSince(start) / 3600) * TimelineGrid.cellWidth
        withAnimation(animated ? .default : nil) { position.scrollTo(x: x) }
    }
}

#Preview {
    WorldView()
}
