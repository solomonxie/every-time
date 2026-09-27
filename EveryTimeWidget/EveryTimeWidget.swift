import SwiftUI
import WidgetKit

@main
struct EveryTimeWidgets: WidgetBundle {
    var body: some Widget {
        WorldClockWidget()
        CountdownWidget()
    }
}

struct GlanceEntry: TimelineEntry {
    let date: Date
    let glance: Glance
}

/// One entry per minute for an hour, so clocks and day counts stay current.
struct GlanceProvider: TimelineProvider {
    private let sample = Glance(
        cities: WorldCity.defaults,
        countdowns: [.init(id: UUID(), name: "Vacation", target: .now.addingTimeInterval(9 * 86_400))]
    )

    func placeholder(in context: Context) -> GlanceEntry { GlanceEntry(date: .now, glance: sample) }

    func getSnapshot(in context: Context, completion: @escaping (GlanceEntry) -> Void) {
        let glance = Glance.load()
        completion(GlanceEntry(date: .now, glance: context.isPreview && glance.cities.isEmpty ? sample : glance))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GlanceEntry>) -> Void) {
        let glance = Glance.load()
        let start = Calendar.current.dateInterval(of: .minute, for: .now)?.start ?? .now
        let entries = (0..<60).map { GlanceEntry(date: start.addingTimeInterval(Double($0) * 60), glance: glance) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct WorldClockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WorldClock", provider: GlanceProvider()) { entry in
            WorldClockView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("World clock")
        .description("Your World cities, in the order you keep them.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct WorldClockView: View {
    let entry: GlanceEntry
    @Environment(\.widgetFamily) private var family

    private var limit: Int {
        switch family {
        case .systemMedium: 4
        case .accessoryRectangular: 2
        default: 3
        }
    }

    var body: some View {
        let cities = Array(entry.glance.cities.prefix(limit))
        if cities.isEmpty {
            Text("Add cities in World").font(.caption).foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: family == .accessoryRectangular ? 0 : 6) {
                ForEach(cities) { city in
                    HStack(alignment: .firstTextBaseline) {
                        Text(city.name).lineLimit(1)
                        if family == .systemMedium {
                            Text(city.offsetLabel(at: entry.date)).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 4)
                        Text(entry.date, format: Date.FormatStyle(date: .omitted, time: .shortened, timeZone: city.timeZone))
                            .monospacedDigit()
                            .fontWeight(.semibold)
                    }
                    .font(family == .accessoryRectangular ? .caption : .subheadline)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

struct CountdownWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Countdown", provider: GlanceProvider()) { entry in
            CountdownWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Countdown")
        .description("Your next countdown.")
        .supportedFamilies([.systemSmall, .accessoryRectangular])
    }
}

struct CountdownWidgetView: View {
    let entry: GlanceEntry

    var body: some View {
        if let next = entry.glance.upcoming(after: entry.date).first {
            let days = Calendar.current.dateComponents([.day], from: entry.date, to: next.target).day ?? 0
            VStack(alignment: .leading, spacing: 2) {
                Text(next.name.isEmpty ? "Countdown" : next.name).font(.caption).lineLimit(2)
                Spacer(minLength: 0)
                if days >= 1 {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(days)").font(.system(.largeTitle, design: .rounded, weight: .semibold))
                        Text(days == 1 ? "day" : "days").font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    Text(next.target, style: .timer)
                        .font(.system(.title, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                }
                Text(next.target, format: .dateTime.month().day().hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            Text("No upcoming countdowns").font(.caption).foregroundStyle(.secondary)
        }
    }
}
