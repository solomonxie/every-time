import SwiftUI

struct OnThisDayView: View {
    @State private var store = OnThisDayStore()
    @State private var date = Date.now
    @State private var section: OnThisDay.Section = .selected

    private var monthDay: (month: Int, day: Int) {
        let parts = Calendar.current.dateComponents([.month, .day], from: date)
        return (parts.month ?? 1, parts.day ?? 1)
    }

    private var isToday: Bool { Calendar.current.isDateInToday(date) }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.spacing) {
                dayPicker
                Picker("Section", selection: $section) {
                    ForEach(OnThisDay.Section.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                content
            }
            .screen()
            .padding(.vertical, 8)
        }
        .overlay { overlay }
        .refreshable { await load(force: true) }
        .task(id: monthDay.month * 100 + monthDay.day) { await load() }
        .navigationTitle("On this day")
        .toolbar {
            if !isToday {
                Button("Today") { withAnimation(.snappy) { date = .now } }
            }
        }
        .sensoryFeedback(.selection, trigger: section)
    }

    private var dayPicker: some View {
        HStack(spacing: Theme.spacing) {
            Button { shift(-1) } label: { Image(systemName: "chevron.left") }
                .buttonStyle(.soft)
                .accessibilityLabel("Previous day")
            Spacer(minLength: 0)
            DatePicker("Day", selection: $date, displayedComponents: .date)
                .labelsHidden()
            Spacer(minLength: 0)
            Button { shift(1) } label: { Image(systemName: "chevron.right") }
                .buttonStyle(.soft)
                .accessibilityLabel("Next day")
        }
    }

    @ViewBuilder
    private var content: some View {
        if case .loaded(let day) = store.phase, !day.isEmpty {
            let entries = day[section]
            if let saved = store.savedCopyDate {
                Label("Offline — saved \(saved.formatted(.relative(presentation: .named)))", systemImage: "wifi.slash")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
            SectionLabel(title: section.rawValue) {
                Text("\(entries.count)").font(.label).foregroundStyle(.tertiary)
            }
            .padding(.top, 4)
            if entries.isEmpty {
                Text("Nothing under \(section.rawValue.lowercased()) for this day.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
            ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                OnThisDayRow(entry: entry)
            }
            Text("From Wikipedia · CC BY-SA 4.0")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        }
    }

    @ViewBuilder
    private var overlay: some View {
        switch store.phase {
        case .loading:
            ProgressView("Asking Wikipedia…")
        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn't load this day", systemImage: "wifi.slash")
            } description: {
                Text(message)
            } actions: {
                Button("Try again") { Task { await load(force: true) } }
                    .buttonStyle(.soft)
            }
        case .loaded(let day) where day.isEmpty:
            ContentUnavailableView("Nothing listed", systemImage: "text.book.closed",
                                   description: Text("Wikipedia has no entries for this day."))
        case .loaded:
            EmptyView()
        }
    }

    private func load(force: Bool = false) async {
        await store.load(month: monthDay.month, day: monthDay.day, force: force)
    }

    private func shift(_ days: Int) {
        if let next = Calendar.current.date(byAdding: .day, value: days, to: date) { date = next }
    }
}

private struct OnThisDayRow: View {
    let entry: OnThisDay.Entry

    var body: some View {
        if let page = entry.pages.first {
            Link(destination: page.url) { card(title: page.title) }
                .buttonStyle(.plain)
                .contextMenu {
                    ForEach(entry.pages, id: \.url) { page in
                        Link(destination: page.url) { Label(page.title, systemImage: "safari") }
                    }
                }
        } else {
            card(title: nil)
        }
    }

    private func card(title: String?) -> some View {
        Card(padding: 14) {
            VStack(alignment: .leading, spacing: 6) {
                if let year = entry.year {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(Self.yearText(year)).font(.clock(28)).foregroundStyle(.tint)
                        Text(Self.ago(year)).font(.label).foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                        if title != nil { linkIcon }
                    }
                    Text(entry.text).font(.subheadline)
                } else {
                    HStack(alignment: .firstTextBaseline) {
                        Text(entry.text).font(.cardTitle)
                        Spacer(minLength: 0)
                        if title != nil { linkIcon }
                    }
                }
                if let title {
                    Text(title).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var linkIcon: some View {
        Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.tertiary)
    }

    private static func yearText(_ year: Int) -> String {
        year < 0 ? "\(-year) BC" : String(year)
    }

    private static func ago(_ year: Int) -> String {
        let now = Calendar.current.component(.year, from: .now)
        let years = year < 0 ? now - year - 1 : now - year
        switch years {
        case ..<1: return "this year"
        case 1: return "1 year ago"
        default: return "\(years.formatted()) years ago"
        }
    }
}

#Preview {
    NavigationStack { OnThisDayView() }
}
