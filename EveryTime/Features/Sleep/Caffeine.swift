import SwiftUI

/// Coffee log for today: when to stop, and whether the last one is still working.
struct Caffeine {
    /// Caffeine's half-life is ~5 h; a cutoff this far before bed keeps most of it out of the night.
    static let hoursBeforeBed = 8.0
    /// Sooner than this after the last cup mostly stacks jitters, not alertness.
    static let minGap: TimeInterval = 90 * 60
    static let keepDays = 30

    var drinks: [Date]

    func today(_ now: Date, calendar: Calendar = .current) -> [Date] {
        drinks.filter { calendar.isDate($0, inSameDayAs: now) }
    }

    func last(before now: Date) -> Date? { drinks.filter { $0 <= now }.max() }

    static func cutoff(bed: Date) -> Date { bed.addingTimeInterval(-hoursBeforeBed * 3600) }

    struct Status: Equatable {
        let text: String
        let level: NapAdvice.Level
    }

    func status(now: Date, bed: Date) -> Status {
        let cutoff = Self.cutoff(bed: bed)
        if now >= cutoff {
            return Status(text: "Past your \(SleepNow.clock(cutoff)) cutoff — it would still be in you at bedtime", level: .high)
        }
        if let last = last(before: now), now.timeIntervalSince(last) < Self.minGap {
            return Status(text: "Too soon — last one \(Int(now.timeIntervalSince(last) / 60)) min ago, wait until \(SleepNow.clock(last.addingTimeInterval(Self.minGap)))",
                          level: .some)
        }
        return Status(text: "Fine until \(SleepNow.clock(cutoff))", level: .low)
    }

    func adding(_ time: Date) -> Caffeine {
        let keepFrom = time.addingTimeInterval(-Double(Self.keepDays) * 86_400)
        return Caffeine(drinks: (drinks + [time]).filter { $0 >= keepFrom }.sorted())
    }
}

/// Today tile: may I have coffee now, and log one.
struct CoffeeTile: View {
    @Stored(NapKey.caffeine) private var drinks: [Date] = []
    let now: Date
    let bed: Date

    var body: some View {
        let caffeine = Caffeine(drinks: drinks)
        let status = caffeine.status(now: now, bed: bed)
        let today = caffeine.today(now)
        let value = switch status.level {
        case .low: "OK now"
        case .some: "Not yet"
        case .high: "Done today"
        }
        let cutoff = SleepNow.clock(Caffeine.cutoff(bed: bed))
        let detail = switch status.level {
        case .low: "Fine until \(cutoff)"
        case .some: "Last cup under \(Int(Caffeine.minGap / 60)) min ago"
        case .high: "Past \(cutoff) cutoff"
        }
        StatTile(symbol: "cup.and.saucer.fill", title: "Coffee", value: value, tint: status.level.tint,
                 detail: detail + (today.isEmpty ? "" : " · \(today.count) today"), info: Self.info) {
            Button { drinks = caffeine.adding(now).drinks } label: {
                Label("Log a cup", systemImage: "plus")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 30)
                    .background(status.level.tint.opacity(0.15), in: Capsule())
            }
            .buttonStyle(.plain)
            .contextMenu {
                if let last = today.last {
                    Button("Undo last cup", systemImage: "arrow.uturn.backward") { drinks.removeAll { $0 == last } }
                }
            }
        }
        .accessibilityHint(status.text)
        .sensoryFeedback(.selection, trigger: drinks.count)
    }

    static let info = """
        Can I have a coffee now? Tap Log a cup when you drink one.
        Cutoff is \(Int(Caffeine.hoursBeforeBed)) h before bed so it's mostly gone by night. \
        Cups under \(Int(Caffeine.minGap / 60)) min apart add jitters, not alertness. Long-press to undo.
        """
}

/// Small square on the Today row: a big value with a line under it.
struct StatTile<Footer: View>: View {
    let symbol: String
    let title: String
    let value: String
    let tint: Color
    let detail: String
    let info: String
    @ViewBuilder var footer: Footer
    @State private var showsInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button { showsInfo = true } label: {
                HStack(spacing: 4) {
                    Label(title, systemImage: symbol).foregroundStyle(tint)
                    Spacer(minLength: 0)
                    Image(systemName: "info.circle").foregroundStyle(.tertiary)
                }
                .font(.caption.weight(.semibold))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showsInfo) {
                Text(info)
                    .font(.subheadline)
                    .padding()
                    .frame(idealWidth: 280)
                    .fixedSize(horizontal: false, vertical: true)
                    .presentationCompactAdaptation(.popover)
            }
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            footer
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        .background(Theme.cardFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

extension StatTile where Footer == EmptyView {
    init(symbol: String, title: String, value: String, tint: Color, detail: String, info: String) {
        self.init(symbol: symbol, title: title, value: value, tint: tint, detail: detail, info: info) { EmptyView() }
    }
}
