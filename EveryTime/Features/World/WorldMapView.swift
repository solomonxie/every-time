import SwiftUI

/// Your saved cities on a dotted world map, with the day/night line where it is now.
struct WorldMapView: View {
    @Stored(WorldCity.storageKey) private var cities = WorldCity.defaults
    @Stored(WorldCity.homeKey) private var home: WorldCity? = nil
    @State private var showingWall = false

    var body: some View {
        TimelineView(.everyMinute) { context in
            let now = context.date
            let local = WorldCity.local(home: home, at: now)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    WorldMap(sun: SunPosition(at: now), cities: cities, local: local).screen()
                    LocalClock(city: local, now: now, size: 56).screen()
                    if !cities.isEmpty { cityList(now: now).screen() }
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("World map")
        .toolbar {
            Button("Full screen", systemImage: "arrow.up.left.and.arrow.down.right") { showingWall = true }
        }
        .fullScreenCover(isPresented: $showingWall) { WorldMapWall(cities: cities, home: home) }
    }

    private func cityList(now: Date) -> some View {
        Card(padding: 0) {
            VStack(spacing: 0) {
                ForEach(cities) { city in
                    row(city, now: now)
                    if city != cities.last { Divider().overlay(Theme.hairline).padding(.leading, 16) }
                }
            }
        }
    }

    private func row(_ city: WorldCity, now: Date) -> some View {
        let isDay = city.coordinate.map { SunPosition(at: now).height(latitude: $0.latitude, longitude: $0.longitude) > 0 }
        return HStack(spacing: Theme.spacing) {
            Image(systemName: isDay == false ? "moon.fill" : "sun.max.fill")
                .foregroundStyle(isDay == false ? Color.indigo : Color.orange)
                .frame(width: 24)
                .opacity(isDay == nil ? 0 : 1)
            Text(city.name)
            Spacer()
            Text(now.formatted(Date.FormatStyle(timeZone: city.timeZone).hour().minute()))
                .font(.clock(17, weight: .regular))
            Text(city.offsetLabel(at: now))
                .font(.label).foregroundStyle(.secondary)
                .frame(minWidth: 44, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 48)
    }
}

/// Sideways and dark, like a bedside clock.
private struct WorldMapWall: View {
    let cities: [WorldCity]
    let home: WorldCity?

    var body: some View {
        SidewaysScreen(horizontalPadding: 36) {
            TimelineView(.everyMinute) { context in
                let local = WorldCity.local(home: home, at: context.date)
                ZStack(alignment: .bottomLeading) {
                    WorldMap(sun: SunPosition(at: context.date), cities: cities, local: local)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    LocalClock(city: local, now: context.date, size: 64)
                }
                .overlay(alignment: .topLeading) { SidewaysCloseButton() }
            }
        }
    }
}

private struct LocalClock: View {
    let city: WorldCity
    let now: Date
    let size: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label(city.name, systemImage: "location.fill")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(WorldMap.pin)
            Text(now.formatted(.dateTime.hour().minute()))
                .font(.clock(size))
                .contentTransition(.numericText())
        }
    }
}

/// Land dots lit by the sun, the day/night line, and a pin per city.
struct WorldMap: View {
    static let pin = Color(red: 1, green: 0.8, blue: 0.35)
    private static let dot = Color(red: 0.72, green: 0.82, blue: 1)
    private static let columns = WorldMapData.land.first?.count ?? 120
    private static let rows = WorldMapData.land.count
    private static let cells: [(row: Int, column: Int, latitude: Double, longitude: Double)] =
        WorldMapData.land.enumerated().flatMap { row, line in
            line.enumerated().compactMap { column, mark in
                mark == "#" ? (row, column, latitude(row: row), longitude(column: column)) : nil
            }
        }

    let sun: SunPosition
    let cities: [WorldCity]
    let local: WorldCity

    var body: some View {
        Canvas { context, size in
            let cell = size.width / CGFloat(Self.columns)
            for land in Self.cells {
                let center = CGPoint(x: (CGFloat(land.column) + 0.5) * cell, y: (CGFloat(land.row) + 0.5) * cell)
                let light = min(1, max(0, (sun.height(latitude: land.latitude, longitude: land.longitude) + 0.1) / 0.2))
                context.fill(Circle().path(in: CGRect(origin: center, size: .zero).insetBy(dx: -cell * 0.31, dy: -cell * 0.31)),
                             with: .color(Self.dot.opacity(0.28 + 0.72 * light)))
            }
            context.stroke(terminator(cell: cell, width: size.width), with: .color(Self.dot.opacity(0.7)), lineWidth: max(1, cell * 0.35))
            for city in cities + [local] {
                guard let point = point(city, cell: cell) else { continue }
                let r = cell * (city == local ? 1.0 : 0.8)
                let circle = Circle().path(in: CGRect(origin: point, size: .zero).insetBy(dx: -r, dy: -r))
                context.fill(circle, with: .color(Self.pin))
                context.stroke(circle, with: .color(.black.opacity(0.6)), lineWidth: max(1, cell * 0.25))
            }
        }
        .aspectRatio(CGFloat(Self.columns) / CGFloat(Self.rows), contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("World map with day and night")
    }

    private func terminator(cell: CGFloat, width: CGFloat) -> Path {
        Path { path in
            let height = CGFloat(Self.rows) * cell
            var drawing = false
            for x in stride(from: 0, through: width, by: 2) {
                let lon = Double(x / width) * 360 - 180
                let y = CGFloat((WorldMapData.top - sun.terminator(longitude: lon)) / WorldMapData.step) * cell
                let point = CGPoint(x: x, y: min(max(y, 0), height))
                if drawing { path.addLine(to: point) } else { path.move(to: point) }
                drawing = (0...height).contains(y)
            }
        }
    }

    private func point(_ city: WorldCity, cell: CGFloat) -> CGPoint? {
        city.coordinate.map {
            CGPoint(x: CGFloat(($0.longitude + 180) / WorldMapData.step) * cell,
                    y: CGFloat((WorldMapData.top - $0.latitude) / WorldMapData.step) * cell)
        }
    }

    private static func latitude(row: Int) -> Double { WorldMapData.top - (Double(row) + 0.5) * WorldMapData.step }
    private static func longitude(column: Int) -> Double { (Double(column) + 0.5) * WorldMapData.step - 180 }
}

#Preview {
    NavigationStack { WorldMapView() }
}
