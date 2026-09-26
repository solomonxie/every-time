import SwiftUI

struct WorldView: View {
    @Stored("world.cities") private var cities: [WorldCity] = [
        WorldCity(timeZoneIdentifier: "America/New_York"),
        WorldCity(timeZoneIdentifier: "Europe/London"),
        WorldCity(timeZoneIdentifier: "Asia/Singapore"),
    ]
    @State private var start = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: .now))!
    @State private var cursor = Date.now
    @State private var followsNow = true
    @State private var position = ScrollPosition()
    @Stored("world.localIndex") private var localIndex = 0
    @State private var showingPicker = false
    @State private var isEditing = false
    @State private var showingWall = false
    @Stored("world.targetHours") private var target = TargetHours.work
    @State private var editingTarget = false
    /// Every city ever added, newest first.
    @Stored("world.recentCities") private var recent: [WorldCity] = []

    private let hours = 24 * 8

    private var rows: [TimelineRow] {
        var rows = cities.map { TimelineRow(city: $0, isLocal: false) }
        rows.insert(TimelineRow(city: .local, isLocal: true), at: min(max(localIndex, 0), rows.count))
        return rows
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                hero.screen()
                VStack(alignment: .leading, spacing: Theme.spacing) {
                    TimelineGrid(rows: rows, start: start, hours: hours, cursor: cursor, position: $position,
                                 isEditing: isEditing, snaps: !followsNow,
                                 onScroll: { if !followsNow { cursor = date(atOffset: $0) } },
                                 onDragStart: { followsNow = false },
                                 onRemove: remove,
                                 onMove: move)
                    if cities.isEmpty {
                        Text("Tap + to add a city to compare")
                            .font(.footnote).foregroundStyle(.secondary).screen()
                    }
                }
                overlapSection.screen()
                recentSection.screen()
            }
            .padding(.vertical, 8)
        }
        .navigationTitle("World")
        .toolbar {
            Button("Full screen", systemImage: "arrow.up.left.and.arrow.down.right") { showingWall = true }
        }
        .fullScreenCover(isPresented: $showingWall) {
            WorldWallView(rows: rows, start: start, hours: hours, cursor: cursor, followsNow: followsNow)
                .environment(\.targetHours, target)
        }
        .bottomBar { bottomBar }
        .sheet(isPresented: $showingPicker) {
            CityPickerView(excluded: Set(cities.map(\.id) + [WorldCity.local.id])) { add($0) }
        }
        .environment(\.targetHours, target)
        .sensoryFeedback(.selection, trigger: target)
        .onAppear { jumpToNow(animated: false) }
        .task { await tickWhileFollowingNow() }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(cursor.formatted(.dateTime.hour().minute()))
                .font(.clock(56))
                .contentTransition(.numericText())
            HStack(spacing: 6) {
                Text(cursor.formatted(.dateTime.weekday(.wide).month().day()))
                Text("·").foregroundStyle(.tertiary)
                Text(relativeLabel).foregroundStyle(followsNow ? Color.secondary : Color.accentColor)
            }
            .font(.label)
            .foregroundStyle(.secondary)
        }
        .animation(.snappy, value: cursor)
    }

    private var relativeLabel: String {
        let minutes = Int((cursor.timeIntervalSinceNow / 60).rounded())
        guard !followsNow, minutes != 0 else { return "Now" }
        let h = abs(minutes) / 60, m = abs(minutes) % 60
        let span = [h > 0 ? "\(h)h" : nil, m > 0 ? "\(m)m" : nil].compactMap { $0 }.joined(separator: " ")
        return minutes > 0 ? "in \(span)" : "\(span) ago"
    }

    // MARK: Overlap

    private var overlapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "Overlap") {
                Text("· " + cursor.formatted(.dateTime.weekday(.abbreviated).day()))
                    .font(.label).foregroundStyle(.tertiary)
            }
            Card {
                let ranges = overlapRanges
                if ranges.isEmpty {
                    Label("No shared target hours this day", systemImage: "moon.zzz")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(ranges, id: \.lowerBound) { range in chip(range) }
                        }
                    }
                }
                Divider().overlay(Theme.hairline)
                targetRow
                if editingTarget { targetEditor }
            }
        }
    }

    private var targetRow: some View {
        Button {
            withAnimation(.snappy) { editingTarget.toggle() }
        } label: {
            HStack {
                Text("Target hours").foregroundStyle(.primary)
                Spacer()
                Text(Self.rangeText(target))
                    .monospacedDigit()
                    .foregroundStyle(editingTarget ? Color.accentColor : .secondary)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(editingTarget ? 90 : 0))
            }
            .font(.subheadline)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Each city's local hours to find an overlap in")
    }

    private var targetEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ForEach([("Work", TargetHours.work), ("Awake", TargetHours.awake)], id: \.0) { name, preset in
                    Button("\(name) \(Self.rangeText(preset))") { withAnimation(.snappy) { target = preset } }
                        .buttonStyle(.soft)
                        .foregroundStyle(target == preset ? Color.accentColor : .primary)
                }
            }
            HStack(spacing: 0) {
                hourWheel("From", selection: $target.start)
                Text("–").foregroundStyle(.secondary)
                hourWheel("To", selection: $target.end)
            }
            Text("In each city's local time").font(.caption).foregroundStyle(.tertiary)
        }
    }

    private func hourWheel(_ title: String, selection: Binding<Int>) -> some View {
        Picker(title, selection: selection) {
            ForEach(0..<24, id: \.self) { Text(Self.hourText($0)).tag($0) }
        }
        .pickerStyle(.wheel)
        .frame(maxWidth: .infinity, maxHeight: 130)
        .clipped()
        .accessibilityLabel(title)
    }

    private static func hourText(_ hour: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now) ?? .now
        return date.formatted(.dateTime.hour())
    }

    private static func rangeText(_ target: TargetHours) -> String {
        target.start == target.end ? "All day" : "\(hourText(target.start)) – \(hourText(target.end))"
    }

    private func chip(_ range: Range<Date>) -> some View {
        let active = range.contains(cursor)
        return Button {
            followsNow = false
            scroll(to: range.lowerBound)
        } label: {
            Text(range.formatted(.interval.hour().minute()))
                .font(.clock(15, weight: .medium))
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
                .foregroundStyle(active ? Color.white : Color.accentColor)
                .background(active ? Color.accentColor : Color.accentColor.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    /// Hour blocks of the cursor's local day where every row is inside the target hours.
    private var overlapRanges: [Range<Date>] {
        let dayStart = Calendar.current.startOfDay(for: cursor)
        let instants = (0..<24).map { dayStart.addingTimeInterval(Double($0) * 3600) }
        var ranges: [Range<Date>] = []
        for instant in instants where rows.allSatisfy({ target.contains($0.calendar.component(.hour, from: instant)) }) {
            let end = instant.addingTimeInterval(3600)
            if let last = ranges.last, last.upperBound == instant {
                ranges[ranges.count - 1] = last.lowerBound..<end
            } else {
                ranges.append(instant..<end)
            }
        }
        return ranges
    }

    // MARK: Recent

    private var hiddenRecent: [WorldCity] {
        recent.filter { city in city.id != WorldCity.local.id && !cities.contains { $0.id == city.id } }
    }

    @ViewBuilder
    private var recentSection: some View {
        let list = hiddenRecent
        if !list.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(title: "Recent") {
                    Spacer()
                    Button("Clear") { withAnimation(.snappy) { recent.removeAll { list.contains($0) } } }
                        .font(.label)
                }
                Card(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(list) { city in
                            recentRow(city)
                            if city != list.last { Divider().overlay(Theme.hairline).padding(.leading, 16) }
                        }
                    }
                }
            }
        }
    }

    private func recentRow(_ city: WorldCity) -> some View {
        Button { add(city) } label: {
            HStack(spacing: Theme.spacing) {
                Text(city.name).foregroundStyle(.primary)
                Spacer()
                Text(cursor.formatted(Date.FormatStyle(timeZone: city.timeZone).hour().minute()))
                    .font(.clock(17, weight: .regular))
                Text(city.offsetLabel(at: cursor))
                    .font(.label).foregroundStyle(.secondary)
                    .frame(minWidth: 44, alignment: .trailing)
                Image(systemName: "plus.circle.fill").foregroundStyle(Color.accentColor)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add \(city.name)")
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 10) {
            Button { jumpToNow() } label: { Label("Now", systemImage: "location.fill") }
                .buttonStyle(.soft)
                .disabled(followsNow)
                .opacity(followsNow ? 0.4 : 1)
            Button(isEditing ? "Done" : "Edit") { withAnimation(.snappy) { isEditing.toggle() } }
                .buttonStyle(.soft)
            Button { showingPicker = true } label: { Label("Add City", systemImage: "plus") }
                .buttonStyle(.primary)
        }
        .sensoryFeedback(.selection, trigger: followsNow) { _, new in new }
    }

    // MARK: Actions

    private func add(_ city: WorldCity) {
        withAnimation(.snappy) {
            if !cities.contains(city) { cities.append(city) }
            recent.removeAll { $0.id == city.id }
            recent.insert(city, at: 0)
            recent = Array(recent.prefix(20))
        }
    }

    /// Cities that predate the history (defaults) join it when removed, so they can be re-added.
    private func remove(_ city: WorldCity) {
        withAnimation(.snappy) {
            cities.removeAll { $0 == city }
            if !recent.contains(where: { $0.id == city.id }) { recent.insert(city, at: 0) }
        }
    }

    private func move(_ id: String, onto targetID: String) {
        var ids = rows.map(\.id)
        guard let from = ids.firstIndex(of: id), let to = ids.firstIndex(of: targetID) else { return }
        ids.move(fromOffsets: [from], toOffset: to > from ? to + 1 : to)
        let localID = WorldCity.local.id
        localIndex = ids.firstIndex(of: localID) ?? 0
        cities = ids.filter { $0 != localID }.compactMap { id in cities.first { $0.id == id } }
    }

    /// Exact current time (no 15-min snap); the cursor keeps following now until the user drags.
    private func jumpToNow(animated: Bool = true) {
        followsNow = true
        cursor = .now
        scroll(to: cursor, animated: animated)
    }

    private func tickWhileFollowingNow() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(15))
            if followsNow { jumpToNow(animated: false) }
        }
    }

    private func date(atOffset x: CGFloat) -> Date {
        start.addingTimeInterval(Double(x / TimelineGrid.cellWidth) * 3600)
    }

    private func scroll(to date: Date, animated: Bool = true) {
        let x = CGFloat(date.timeIntervalSince(start) / 3600) * TimelineGrid.cellWidth
        withAnimation(animated ? .snappy : nil) { position.scrollTo(x: x) }
    }
}

#Preview {
    WorldView()
}
