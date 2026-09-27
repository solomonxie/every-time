import SwiftUI

/// Due dates and calendar milestones across weeks. BoardView provides the scroll view.
struct BoardRoadmapView: View {
    let config: BoardConfig
    let cards: [BoardCard]
    let onOpen: (BoardCard) -> Void

    @State private var milestones: [BoardStore.Milestone] = []
    @State private var showUndated = false
    private let store = BoardStore.shared

    private static let labelWidth: CGFloat = 124
    private static let rowHeight: CGFloat = 44

    var body: some View {
        let metrics = BoardMetrics(cards: cards)
        let map = metrics.roadmap(milestones: milestones)
        VStack(alignment: .leading, spacing: Theme.spacing) {
            if map.rows.isEmpty && map.milestones.isEmpty {
                Card {
                    Text("No due dates yet").font(.cardTitle)
                    Text("Give cards a due date to see them across weeks.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            } else {
                Card(padding: 12) {
                    VStack(spacing: 0) {
                        header(map)
                        ForEach(map.milestones) { milestoneRow($0, map) }
                        ForEach(map.rows) { cardRow($0, map, metrics) }
                    }
                    if !map.rows.isEmpty { legend(map.rows) }
                }
            }
            if !map.undated.isEmpty { undated(map.undated) }
            if config.milestoneCalendarID == nil {
                Text("Pick a calendar in ⋯ to show milestones")
                    .font(.footnote).foregroundStyle(.secondary).padding(.horizontal, 4)
            }
        }
        .task(id: "\(store.revision)|\(config.milestoneCalendarID ?? "")") {
            milestones = store.milestones(in: config.milestoneCalendarID)
        }
    }

    // MARK: Rows

    private func header(_ map: BoardMetrics.Roadmap) -> some View {
        HStack(spacing: 8) {
            Color.clear.frame(width: Self.labelWidth)
            GeometryReader { geo in
                let every = max(1, Int((Double(map.weekStarts.count) * 52 / geo.size.width).rounded(.up)))
                ForEach(Array(map.weekStarts.enumerated()), id: \.offset) { index, week in
                    if index % every == 0 {
                        Text(week, format: .dateTime.month(.abbreviated).day())
                            .fixedSize()
                            .position(x: min(map.position(of: week) * geo.size.width + 22, geo.size.width - 22), y: 8)
                    }
                }
                Text("today")
                    .foregroundStyle(.tint)
                    .fixedSize()
                    .position(x: todayX(map, width: geo.size.width), y: 26)
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
            .background(alignment: .bottom) { Lanes(map: map).frame(height: 10) }
        }
        .frame(height: 36)
        .accessibilityHidden(true)
    }

    private func todayX(_ map: BoardMetrics.Roadmap, width: CGFloat) -> CGFloat {
        min(max(map.position(of: .now) * width, 16), width - 16)
    }

    private func milestoneRow(_ milestone: BoardStore.Milestone, _ map: BoardMetrics.Roadmap) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Label(milestone.title, systemImage: "diamond.fill")
                    .labelStyle(MilestoneLabelStyle())
                    .font(.subheadline.weight(.semibold))
                Text(milestone.date, format: .dateTime.month(.abbreviated).day())
                    .font(.caption).foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .frame(width: Self.labelWidth, alignment: .leading)
            GeometryReader { geo in
                let x = map.position(of: milestone.date) * geo.size.width
                ZStack(alignment: .topLeading) {
                    Lanes(map: map)
                    Path { $0.move(to: CGPoint(x: 0, y: geo.size.height / 2)); $0.addLine(to: CGPoint(x: x, y: geo.size.height / 2)) }
                        .stroke(.secondary, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                        .position(x: x, y: geo.size.height / 2)
                }
            }
        }
        .frame(height: Self.rowHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Milestone \(milestone.title), \(milestone.date.formatted(date: .abbreviated, time: .omitted))")
    }

    private func cardRow(_ card: BoardCard, _ map: BoardMetrics.Roadmap, _ metrics: BoardMetrics) -> some View {
        let overdue = metrics.isOverdue(card)
        let due = metrics.dueDate(card) ?? .now
        return Button { onOpen(card) } label: {
            HStack(spacing: 8) {
                Text(card.title)
                    .font(.subheadline)
                    .lineLimit(1)
                    .frame(width: Self.labelWidth, alignment: .leading)
                GeometryReader { geo in
                    let x = map.position(of: due) * geo.size.width
                    ZStack(alignment: .topLeading) {
                        Lanes(map: map)
                        Circle()
                            .fill(BoardPalette.color(of: card, in: config))
                            .frame(width: 10, height: 10)
                            .padding(2)
                            .background(Circle().fill(Color(.systemBackground)))
                            .position(x: x, y: geo.size.height / 2)
                        if overdue {
                            Text("!")
                                .font(.subheadline.weight(.heavy))
                                .foregroundStyle(Theme.Tone.bad)
                                .position(x: x + (x > geo.size.width - 14 ? -12 : 12), y: geo.size.height / 2)
                        }
                    }
                }
            }
            .frame(height: Self.rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(rowLabel(card, due: due, overdue: overdue))
    }

    private func rowLabel(_ card: BoardCard, due: Date, overdue: Bool) -> String {
        let column = config.column(of: card)?.name ?? BoardConfig.doneName
        return "\(card.title), due \(due.formatted(date: .abbreviated, time: .omitted)), \(column)" + (overdue ? ", overdue" : "")
    }

    private func legend(_ rows: [BoardCard]) -> some View {
        let names = BoardMetrics.columnNames(config)
        let colors = BoardPalette.colors(config)
        let shown = Set(rows.map { config.column(of: $0)?.name ?? BoardConfig.doneName })
        return BoardLegend(items: names.indices.filter { shown.contains(names[$0]) }.map { (names[$0], colors[$0]) })
    }

    private func undated(_ undated: [BoardCard]) -> some View {
        Card(padding: 12) {
            Button {
                withAnimation(.snappy) { showUndated.toggle() }
            } label: {
                HStack {
                    Text("No date: \(undated.count) \(undated.count == 1 ? "card" : "cards")")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(showUndated ? 90 : 0))
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
                .frame(minHeight: 32)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if showUndated {
                ForEach(undated) { card in
                    Button { onOpen(card) } label: {
                        HStack(spacing: 10) {
                            Circle().fill(BoardPalette.color(of: card, in: config)).frame(width: 8, height: 8)
                            Text(card.title).font(.subheadline).lineLimit(1)
                            Spacer()
                            Text(config.column(of: card)?.name ?? "").font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(minHeight: 36)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// Week gridlines, today and milestone lines, drawn per row so they line up across rows.
private struct Lanes: View {
    let map: BoardMetrics.Roadmap

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            Path { path in
                for week in map.weekStarts {
                    let x = map.position(of: week) * w
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: h))
                }
            }
            .stroke(Theme.hairline, lineWidth: 1)
            Path { path in
                for milestone in map.milestones {
                    let x = map.position(of: milestone.date) * w
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: h))
                }
            }
            .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
            Path { path in
                let x = map.position(of: .now) * w
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: h))
            }
            .stroke(Color.accentColor.opacity(0.7), lineWidth: 1.5)
        }
        .allowsHitTesting(false)
    }
}

private struct MilestoneLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon.font(.system(size: 9)).foregroundStyle(.secondary)
            configuration.title
        }
    }
}
