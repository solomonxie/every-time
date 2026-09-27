import Charts
import SwiftUI

/// Progress, burn-up, velocity, flow and per-column counts. BoardView provides the scroll view.
struct BoardInsightsView: View {
    let config: BoardConfig
    let cards: [BoardCard]

    @State private var history: [(date: Date, counts: BoardFlow.Day)] = []
    @State private var burnSelection: Date?
    @State private var velocitySelection: Date?
    private let store = BoardStore.shared

    init(config: BoardConfig, cards: [BoardCard]) {
        self.config = config
        self.cards = cards
        _history = State(initialValue: BoardFlow.history(board: config.listID))
    }

    private static let dayFormat = Date.FormatStyle.dateTime.month(.abbreviated).day()

    var body: some View {
        let metrics = BoardMetrics(cards: cards)
        VStack(alignment: .leading, spacing: 24) {
            section("Progress") { progress(metrics.progress) }
            section("Burn-up · \(BoardMetrics.weekCount) weeks") { burnUp(metrics.burnUp) }
            section("Velocity · per week") { velocity(metrics) }
            section(flowTitle) { flow }
            section("By column") { byColumn(metrics.byColumn(config)) }
        }
        .task(id: store.revision) { history = BoardFlow.history(board: config.listID) }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title)
            Card { content() }
        }
    }

    // MARK: Progress

    private func progress(_ p: BoardMetrics.Progress) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(p.fraction, format: .percent.precision(.fractionLength(0))).font(.clock(44))
                Text("\(p.done) done · \(p.open) open").font(.subheadline).foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                Capsule().fill(Color.accentColor.opacity(0.18))
                    .overlay(alignment: .leading) {
                        Capsule().fill(Color.accentColor).frame(width: geo.size.width * p.fraction)
                    }
            }
            .frame(height: 8)
            .accessibilityHidden(true)
            HStack(spacing: 12) {
                if p.overdue > 0 {
                    Label("\(p.overdue) overdue", systemImage: "exclamationmark.circle.fill")
                        .foregroundStyle(Theme.Tone.bad)
                }
                if p.dueThisWeek > 0 {
                    Label("\(p.dueThisWeek) due this week", systemImage: "calendar")
                        .foregroundStyle(.secondary)
                }
                if p.overdue == 0 && p.dueThisWeek == 0 {
                    Text("Nothing overdue or due this week").foregroundStyle(.secondary)
                }
            }
            .font(.footnote)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Burn-up

    private static let created = "Total"
    private static let completed = "Completed"

    private func burnUp(_ points: [BoardMetrics.BurnPoint]) -> some View {
        let selected = burnSelection.flatMap { date in points.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) } }
        return Chart {
            ForEach(points, id: \.date) { point in
                LineMark(x: .value("Date", point.date), y: .value("Cards", point.created), series: .value("Series", Self.created))
                    .foregroundStyle(by: .value("Series", Self.created))
                    .lineStyle(Self.line)
                LineMark(x: .value("Date", point.date), y: .value("Cards", point.completed), series: .value("Series", Self.completed))
                    .foregroundStyle(by: .value("Series", Self.completed))
                    .lineStyle(Self.line)
            }
            if let last = points.last {
                endDot(last.date, last.created, Self.created)
                endDot(last.date, last.completed, Self.completed)
            }
            if let selected {
                RuleMark(x: .value("Date", selected.date))
                    .foregroundStyle(Color.secondary.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        Tooltip(title: selected.date.formatted(Self.dayFormat),
                                lines: ["\(selected.created) total", "\(selected.completed) completed"])
                    }
            }
        }
        .chartForegroundStyleScale([Self.created: BoardPalette.color(0), Self.completed: BoardPalette.color(1)])
        .chartLegend(position: .top, alignment: .leading)
        .chartXAxis { weekAxis }
        .chartYAxis { AxisMarks(position: .leading) { AxisGridLine(); AxisValueLabel() } }
        .chartXSelection(value: $burnSelection)
        .frame(height: 180)
    }

    private func endDot(_ date: Date, _ value: Int, _ series: String) -> some ChartContent {
        PointMark(x: .value("Date", date), y: .value("Cards", value))
            .symbolSize(64)
            .foregroundStyle(by: .value("Series", series))
            .annotation(position: .trailing, spacing: 4) {
                Text("\(value)").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
    }

    private static let line = StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
    private static let grid = StrokeStyle(lineWidth: 0.5)

    private var weekAxis: some AxisContent {
        AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { _ in
            AxisGridLine(stroke: Self.grid)
            AxisValueLabel(format: Self.dayFormat)
        }
    }

    // MARK: Velocity

    private func velocity(_ metrics: BoardMetrics) -> some View {
        let weeks = metrics.velocity
        let unit = metrics.usesPoints ? "pts" : "cards"
        let selected = velocitySelection.flatMap { date in weeks.last { $0.start <= date } }
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("avg").foregroundStyle(.secondary)
                Text(metrics.velocityAverage, format: .number.precision(.fractionLength(1))).font(.clock(28))
                Text(unit).foregroundStyle(.secondary)
            }
            .font(.subheadline)
            .accessibilityElement(children: .combine)
            Chart {
                ForEach(weeks, id: \.start) { week in
                    BarMark(x: .value("Week", week.start, unit: .weekOfYear), y: .value(unit, week.value), width: .fixed(18))
                        .foregroundStyle(BoardPalette.color(0).opacity(selected == nil || selected == week ? 1 : 0.4))
                        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4))
                }
                RuleMark(y: .value("Average", metrics.velocityAverage))
                    .foregroundStyle(Color.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1))
                if let selected {
                    RuleMark(x: .value("Week", selected.start, unit: .weekOfYear))
                        .foregroundStyle(.clear)
                        .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                            Tooltip(title: "Week of \(selected.start.formatted(Self.dayFormat))", lines: ["\(selected.value) \(unit)"])
                        }
                }
            }
            .chartXAxis { weekAxis }
            .chartYAxis { AxisMarks(position: .leading) { AxisGridLine(); AxisValueLabel() } }
            .chartXSelection(value: $velocitySelection)
            .frame(height: 140)
        }
    }

    // MARK: Flow

    private var flowTitle: String {
        guard let first = history.first, history.count >= 2 else { return "Flow" }
        return "Flow · since \(first.date.formatted(Self.dayFormat))"
    }

    @ViewBuilder private var flow: some View {
        if history.count < 2 {
            Label("Builds up from today — check back in a few days", systemImage: "chart.line.uptrend.xyaxis")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            let names = BoardMetrics.columnNames(config)
            Chart(BoardMetrics.flow(history, columns: names), id: \.self) { point in
                AreaMark(x: .value("Date", point.date, unit: .day), y: .value("Cards", point.count), stacking: .standard)
                    .foregroundStyle(by: .value("Column", point.column))
            }
            .chartForegroundStyleScale(domain: names, range: BoardPalette.colors(config))
            .chartLegend(position: .top, alignment: .leading)
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in AxisGridLine(stroke: Self.grid); AxisValueLabel(format: Self.dayFormat) } }
            .chartYAxis { AxisMarks(position: .leading) { AxisGridLine(); AxisValueLabel() } }
            .frame(height: 180)
        }
    }

    // MARK: By column

    private func byColumn(_ counts: [BoardMetrics.ColumnCount]) -> some View {
        let most = max(counts.map(\.count).max() ?? 0, 1)
        let colors = BoardPalette.colors(config)
        return VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(counts.enumerated()), id: \.offset) { index, column in
                HStack(spacing: 10) {
                    Text(column.name).font(.subheadline).lineLimit(1).frame(width: 104, alignment: .leading)
                    GeometryReader { geo in
                        UnevenRoundedRectangle(bottomTrailingRadius: 4, topTrailingRadius: 4)
                            .fill(colors[index])
                            .frame(width: max(geo.size.width * Double(column.count) / Double(most), column.count > 0 ? 4 : 0))
                            .frame(maxHeight: .infinity)
                    }
                    .frame(height: 14)
                    Text("\(column.count)").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                        .frame(minWidth: 24, alignment: .trailing)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(column.name), \(column.count) \(column.count == 1 ? "card" : "cards")")
            }
        }
    }
}

private struct Tooltip: View {
    let title: String
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            ForEach(lines, id: \.self) { Text($0).font(.caption.monospacedDigit()) }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
