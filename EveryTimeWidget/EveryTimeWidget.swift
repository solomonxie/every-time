import WidgetKit
import SwiftUI

struct EveryTimeEntry: TimelineEntry {
    let date: Date
    let city: String
    let placeholderTime: String
}

struct EveryTimeTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> EveryTimeEntry {
        EveryTimeEntry(date: Date(), city: "San Francisco", placeholderTime: "9:41 AM")
    }

    func getSnapshot(in context: Context, completion: @escaping (EveryTimeEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EveryTimeEntry>) -> Void) {
        let entry = placeholder(in: context)
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct EveryTimeWidgetEntryView: View {
    var entry: EveryTimeTimelineProvider.Entry

    var body: some View {
        VStack(alignment: .leading) {
            Text(entry.city)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(entry.placeholderTime)
                .font(.title2.monospacedDigit())
        }
        .padding()
    }
}

@main
struct EveryTimeWidget: Widget {
    let kind = "EveryTimeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EveryTimeTimelineProvider()) { entry in
            EveryTimeWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("World Clock")
        .description("Shows the current time in a saved city.")
        .supportedFamilies([.systemSmall])
    }
}
