import SwiftUI

/// One column's cards as shown on the board; `column == nil` is Done.
struct BoardLane: Identifiable {
    let column: BoardColumn?
    let cards: [BoardCard]

    var id: String { column?.id.uuidString ?? BoardConfig.doneName }
    var name: String { column?.name ?? BoardConfig.doneName }
}

/// Columns paged horizontally with the next one peeking; cards drag between them.
struct BoardColumnsView: View {
    let lanes: [BoardLane]
    let onOpen: (BoardCard) -> Void
    let onAdd: (BoardColumn) -> Void
    let onMove: (BoardCard, BoardColumn?) -> Void
    let onDelete: (BoardCard) -> Void

    @State private var page: String?
    @State private var hovered: String?

    private var current: String? { page ?? lanes.first?.id }

    var body: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: Theme.spacing) {
                    ForEach(lanes) { lane in
                        LaneView(lane: lane, lanes: lanes, isTargeted: hovered == lane.id,
                                 onOpen: onOpen, onAdd: onAdd, onMove: onMove, onDelete: onDelete)
                            .containerRelativeFrame(.horizontal) { width, _ in width * 0.88 }
                            .dropDestination(for: String.self) { ids, _ in drop(ids, on: lane) } isTargeted: { target(lane, $0) }
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, Theme.padding, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $page)

            HStack(spacing: 8) {
                ForEach(lanes) { lane in
                    Circle()
                        .fill(lane.id == current ? Color.primary : Color.primary.opacity(0.2))
                        .frame(width: 7, height: 7)
                        .onTapGesture { withAnimation(.snappy) { page = lane.id } }
                }
            }
            .accessibilityHidden(true)
            .padding(.bottom, 6)
        }
        .sensoryFeedback(.selection, trigger: hovered) { _, new in new != nil }
    }

    private func drop(_ ids: [String], on lane: BoardLane) -> Bool {
        hovered = nil
        guard let id = ids.first,
              let source = lanes.first(where: { $0.cards.contains { $0.id == id } }),
              source.id != lane.id,
              let card = source.cards.first(where: { $0.id == id }) else { return false }
        onMove(card, lane.column)
        return true
    }

    /// Holding a card over the peeking column pages to it.
    private func target(_ lane: BoardLane, _ isTargeted: Bool) {
        if isTargeted {
            hovered = lane.id
            guard lane.id != current else { return }
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                if hovered == lane.id { withAnimation(.snappy) { page = lane.id } }
            }
        } else if hovered == lane.id {
            hovered = nil
        }
    }
}

private struct LaneView: View {
    let lane: BoardLane
    let lanes: [BoardLane]
    let isTargeted: Bool
    let onOpen: (BoardCard) -> Void
    let onAdd: (BoardColumn) -> Void
    let onMove: (BoardCard, BoardColumn?) -> Void
    let onDelete: (BoardCard) -> Void

    @Environment(\.openURL) private var openURL

    private var atLimit: Bool { lane.column?.wipLimit.map { lane.cards.count >= $0 } ?? false }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: lane.name) {
                Group {
                    if let limit = lane.column?.wipLimit {
                        Text("\(lane.cards.count)/\(limit)\(atLimit ? " ⚠" : "")")
                            .foregroundStyle(atLimit ? AnyShapeStyle(Theme.Tone.warn) : AnyShapeStyle(.tertiary))
                    } else {
                        Text("\(lane.cards.count)").foregroundStyle(.tertiary)
                    }
                }
                .font(.label)
                .monospacedDigit()
                .contentTransition(.numericText())
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if lane.cards.isEmpty {
                        Text("Nothing here")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 8)
                    }
                    ForEach(lane.cards) { card in
                        Button { onOpen(card) } label: { BoardCardRow(card: card) }
                            .buttonStyle(.plain)
                            .contextMenu { menu(for: card) }
                            .draggable(card.id) { BoardCardRow(card: card).frame(width: 280) }
                    }
                    if let column = lane.column {
                        Button { onAdd(column) } label: {
                            Label("Add card", systemImage: "plus.circle")
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .frame(minHeight: 44)
                                .padding(.horizontal, 4)
                        }
                        .foregroundStyle(.tint)
                    }
                }
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
        }
        .padding(6)
        .frame(maxHeight: .infinity, alignment: .top)
        .background {
            RoundedRectangle(cornerRadius: Theme.radius + 4, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(isTargeted ? 0.6 : 0), lineWidth: 2)
                .background(Color.accentColor.opacity(isTargeted ? 0.06 : 0),
                            in: RoundedRectangle(cornerRadius: Theme.radius + 4, style: .continuous))
        }
        .contentShape(Rectangle())
        .animation(.snappy, value: isTargeted)
    }

    @ViewBuilder
    private func menu(for card: BoardCard) -> some View {
        Menu {
            ForEach(lanes) { target in
                if target.id == lane.id {
                    Button {} label: { Label(target.name, systemImage: "checkmark") }.disabled(true)
                } else {
                    Button(target.name) { onMove(card, target.column) }
                }
            }
        } label: {
            Label("Move to", systemImage: "arrow.right.square")
        }
        if let url = card.remindersURL {
            Button { openURL(url) } label: { Label("Open in Reminders", systemImage: "arrow.up.forward.app") }
        }
        Divider()
        Button(role: .destructive) { onDelete(card) } label: { Label("Delete…", systemImage: "trash") }
    }
}

/// Title, then due · priority · points · notes.
struct BoardCardRow: View {
    let card: BoardCard
    var now: Date = .now

    var body: some View {
        Card(padding: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(card.title.isEmpty ? "Untitled" : card.title)
                    .font(.cardTitle)
                    .lineLimit(2)
                    .foregroundStyle(card.isCompleted ? .secondary : .primary)
                if let meta { meta.font(.subheadline).lineLimit(1) }
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
    }

    private var meta: Text? {
        var parts: [Text] = []
        if let due = card.dueDate { parts.append(dueText(due)) }
        let priority = CardPriority(card.priority)
        if priority != .none {
            parts.append(Text(priority.title).fontWeight(.bold)
                .foregroundStyle(card.isCompleted ? Color.secondary : Theme.Tone.warn))
        }
        if let points = card.points, points > 0 {
            parts.append(Text("\(points) \(points == 1 ? "pt" : "pts")").foregroundStyle(.secondary))
        }
        if !card.notes.isEmpty { parts.append(Text(Image(systemName: "note.text")).foregroundStyle(.secondary)) }
        guard let first = parts.first else { return nil }
        return parts.dropFirst().reduce(first) { $0 + Text(" · ").foregroundStyle(.secondary) + $1 }
    }

    private func dueText(_ due: Date) -> Text {
        let calendar = Calendar.current
        var label = calendar.isDateInToday(due) ? "Today"
            : calendar.isDateInTomorrow(due) ? "Tomorrow"
            : calendar.isDate(due, equalTo: now, toGranularity: .year) ? due.formatted(.dateTime.month(.abbreviated).day())
            : due.formatted(.dateTime.month(.abbreviated).day().year())
        if card.dueHasTime { label += " " + due.formatted(date: .omitted, time: .shortened) }
        let style: Color = card.isCompleted ? .secondary
            : card.isOverdue(now: now) ? Theme.Tone.bad
            : calendar.isDateInToday(due) ? .accentColor
            : .secondary
        return (Text(Image(systemName: "alarm")) + Text(" " + label)).foregroundStyle(style)
    }
}
