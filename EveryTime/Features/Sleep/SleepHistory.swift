import SwiftUI

/// Every sleep, nights and naps together, newest first; tap a logged one to edit it.
struct SleepHistory: View {
    let nights: [PastNight]
    let naps: [Nap]
    let now: Date
    let need: TimeInterval
    let advice: NapAdvice
    let health: HealthState
    let onLog: () -> Void
    let onEdit: (Nap) -> Void
    let onDelete: (Nap) -> Void
    let onAddHealth: () -> Void

    @State private var showsAll = false

    enum HealthState { case unavailable, notAsked, loading, empty, loaded }

    private enum Entry: Identifiable {
        case night(PastNight), nap(Nap)
        var id: String { switch self { case .night(let n): "n\(n.id.timeIntervalSinceReferenceDate)"; case .nap(let n): n.id.uuidString } }
        var start: Date { switch self { case .night(let n): n.start; case .nap(let n): n.start } }
    }

    var body: some View {
        let byID = Dictionary(naps.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let entries = (nights.map(Entry.night) + naps.filter { !$0.isNight }.map(Entry.nap)).sorted { $0.start > $1.start }
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel(title: "History") { InfoButton(label: "About history", text: Self.info) }
                Spacer()
                Button(action: onLog) { Image(systemName: "plus.circle.fill").font(.title3) }
                    .accessibilityLabel("Log past sleep")
            }
            if entries.isEmpty {
                Text("Nights and naps you sleep or log show up here; nights get a score.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            if let latest = naps.filter({ $0.end <= now && now.timeIntervalSince($0.end) < 86_400 }).max(by: { $0.end < $1.end }),
               latest.energy == nil {
                SleepFeedback(question: latest.isNight ? "How rested did last night leave you?" : "How rested after your \(latest.minutes)-min nap?",
                              energy: Binding(get: { nil }, set: { NapSession.rate(latest.id, energy: $0) }))
            }
            ForEach(showsAll ? entries : Array(entries.prefix(5))) { entry in
                switch entry {
                case .night(let night):
                    let own = night.source.flatMap { byID[$0] }
                    let row = PastNightRow(night: night, need: need)
                    if let own {
                        editable(row, own)
                    } else {
                        row.contextMenu { Text("From Health") }
                    }
                case .nap(let nap):
                    editable(NapRow(nap: nap, level: advice.tonight(start: nap.start, minutes: nap.minutes)), nap)
                }
            }
            if entries.count > 5 {
                Button(showsAll ? "Show less" : "Show all \(entries.count)") { showsAll.toggle() }.font(.label)
            }
            switch health {
            case .notAsked:
                Button(action: onAddHealth) {
                    Label("Add nights from Health", systemImage: "heart.text.square").font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderless)
            case .empty:
                Text("No sleep in Health for the last two weeks. Check Settings › Health › Data Access › Every Time.")
                    .font(.footnote).foregroundStyle(.secondary)
            case .unavailable, .loading, .loaded:
                EmptyView()
            }
        }
    }

    private func editable(_ row: some View, _ nap: Nap) -> some View {
        Button { onEdit(nap) } label: { row.contentShape(Rectangle()) }
            .buttonStyle(.plain)
            .accessibilityHint("Edit")
            .contextMenu {
                Button("Edit", systemImage: "slider.horizontal.3") { onEdit(nap) }
                Button("Delete", systemImage: "trash", role: .destructive) { onDelete(nap) }
            }
    }

    private static let info = """
        Nights and naps slept from here or logged, plus the Health app's nights on days with nothing logged. \
        A sleep under 3 h is a nap. Each logged night counts; from Health, the longest sleep that day. \
        Score 0–100: up to 60 for sleep against what you need, 20 for waking between cycles, 20 for how rested you felt.
        """
}
