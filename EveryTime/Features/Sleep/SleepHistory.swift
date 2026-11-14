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
    let onOpen: (SleepSession) -> Void
    let onDelete: (Nap) -> Void
    let onAddHealth: () -> Void

    @State private var showsAll = false

    enum HealthState { case unavailable, notAsked, loading, empty, loaded }

    private enum Entry: Identifiable {
        case night(PastNight), nap(SleepSession), missed(DateInterval)
        var id: String {
            switch self {
            case .night(let n): "n\(n.id.timeIntervalSinceReferenceDate)"
            case .nap(let s): s.id.uuidString
            case .missed(let w): "m\(w.start.timeIntervalSinceReferenceDate)"
            }
        }
        var start: Date { switch self { case .night(let n): n.start; case .nap(let n): n.start; case .missed(let w): w.start } }
    }

    var body: some View {
        let sessions = SleepSession.group(naps)
        let missed = SleepTrend.missedNaps(nights, naps: naps, advice: advice, now: now)
        let entries = (nights.map(Entry.night) + sessions.filter { !$0.isNight }.map(Entry.nap) + missed.map(Entry.missed))
            .sorted { $0.start > $1.start }
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
            if let latest = sessions.first(where: { $0.end <= now && now.timeIntervalSince($0.end) < 86_400 }),
               latest.energy == nil, let last = latest.parts.last {
                SleepFeedback(question: latest.isNight ? "How rested did last night leave you?" : "How rested after your \(Int(latest.inBed / 60))-min nap?",
                              energy: Binding(get: { nil }, set: { NapSession.rate(last.id, energy: $0) }))
            }
            ForEach(showsAll ? entries : Array(entries.prefix(5))) { entry in
                switch entry {
                case .night(let night):
                    let row = PastNightRow(night: night, need: need)
                    if let session = night.session {
                        editable(row, session)
                    } else {
                        row.contextMenu { Text("From Health") }
                    }
                case .nap(let session):
                    editable(NapRow(session: session, level: advice.tonight(start: session.start, minutes: Int(session.inBed / 60))), session)
                case .missed(let window):
                    MissedNapRow(window: window)
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

    /// One part: straight to its editor. Several: their details first.
    @ViewBuilder
    private func editable(_ row: some View, _ session: SleepSession) -> some View {
        if let nap = session.parts.first, session.parts.count == 1 {
            Button { onEdit(nap) } label: { row.contentShape(Rectangle()) }
                .buttonStyle(.plain)
                .accessibilityHint("Edit")
                .contextMenu {
                    Button("Edit", systemImage: "slider.horizontal.3") { onEdit(nap) }
                    Button("Delete", systemImage: "trash", role: .destructive) { onDelete(nap) }
                }
        } else {
            Button { onOpen(session) } label: { row.contentShape(Rectangle()) }
                .buttonStyle(.plain)
                .accessibilityHint("Details")
        }
    }

    private static let info = """
        Nights and naps slept from here or logged, plus the Health app's nights on days with nothing logged. \
        A sleep under 3 h is a nap; sleeps with up to 15 min awake between them count as one. \
        Each logged night counts; from Health, the longest sleep that day. \
        Score 0–100: up to 60 for sleep against what you need, 20 for waking between cycles, 20 for how rested you felt.
        With a daily nap on, a day whose nap window passed without one shows as a missed nap.
        """
}

struct MissedNapRow: View {
    let window: DateInterval

    var body: some View {
        SleepHistoryRow(date: window.start, detail: "No nap \(SleepNow.clock(window.start)) – \(SleepNow.clock(window.end))",
                        duration: "Missed") {
            Image(systemName: "powersleep").font(.title3).frame(width: 30, height: 22).foregroundStyle(Theme.Tone.warn)
        }
    }
}
