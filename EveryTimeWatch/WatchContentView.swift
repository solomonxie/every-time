import SwiftUI

struct WatchContentView: View {
    var body: some View {
        TabView {
            WorldPage()
            CountdownsPage()
            SleepPage()
        }
        .tabViewStyle(.verticalPage)
    }
}

private struct WorldPage: View {
    @Environment(WatchStore.self) private var store

    var body: some View {
        TimelineView(.everyMinute) { context in
            List {
                if store.glance.cities.isEmpty { EmptyHint() }
                ForEach(store.glance.cities) { city in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading) {
                            Text(city.name).lineLimit(1)
                            Text(city.offsetLabel(at: context.date).isEmpty ? "Here" : city.offsetLabel(at: context.date))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 4)
                        Text(context.date, format: Date.FormatStyle(date: .omitted, time: .shortened, timeZone: city.timeZone))
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                            .monospacedDigit()
                    }
                }
            }
            .navigationTitle("World")
        }
    }
}

private struct CountdownsPage: View {
    @Environment(WatchStore.self) private var store

    var body: some View {
        TimelineView(.everyMinute) { context in
            let upcoming = store.glance.upcoming(after: context.date)
            List {
                if upcoming.isEmpty {
                    Text("No upcoming countdowns").foregroundStyle(.secondary)
                }
                ForEach(upcoming) { item in
                    let days = Calendar.current.dateComponents([.day], from: context.date, to: item.target).day ?? 0
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name.isEmpty ? "Countdown" : item.name).font(.caption).lineLimit(2)
                        if days >= 1 {
                            Text("\(days) \(days == 1 ? "day" : "days")")
                                .font(.system(.title3, design: .rounded, weight: .semibold))
                        } else {
                            Text(item.target, style: .timer)
                                .font(.system(.title3, design: .rounded, weight: .semibold))
                                .monospacedDigit()
                        }
                        Text(item.target, format: .dateTime.month().day().hour().minute())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Countdown")
        }
    }
}

private struct SleepPage: View {
    var body: some View {
        TimelineView(.everyMinute) { context in
            List {
                Section("Sleep now, wake at") {
                    ForEach(SleepSuggestion.wakeTimes(goingToBedAt: context.date)) { option in
                        HStack {
                            Text(option.time, format: .dateTime.hour().minute())
                                .font(.system(.title3, design: .rounded, weight: .semibold))
                                .foregroundStyle(option.isRecommended ? Color.accentColor : .primary)
                            Spacer()
                            Text("\(option.cycles) cycles").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Sleep")
        }
    }
}

private struct EmptyHint: View {
    var body: some View {
        Text("Open Every Time on your iPhone to sync cities.")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

#Preview {
    WatchContentView().environment(WatchStore())
}
