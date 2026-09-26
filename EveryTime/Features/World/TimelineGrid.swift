import SwiftUI

struct TimelineRow: Identifiable {
    let city: WorldCity
    let isLocal: Bool
    var id: String { city.id }

    var calendar: Calendar {
        var calendar = Calendar.current
        calendar.timeZone = city.timeZone
        return calendar
    }
}

enum HourShade {
    case night, edge, work

    init(hour: Int) {
        switch hour {
        case 8..<18: self = .work
        case 6..<8, 18..<22: self = .edge
        default: self = .night
        }
    }

    var color: Color {
        switch self {
        case .night: .indigo.opacity(0.35)
        case .edge: .orange.opacity(0.18)
        case .work: .green.opacity(0.3)
        }
    }
}

/// World Time Buddy–style grid: pinned city labels, hour strips sharing one horizontal scroll,
/// a fixed center cursor whose instant drives every label.
struct TimelineGrid: View {
    static let cellWidth: CGFloat = 40
    static let rowHeight: CGFloat = 60
    static let labelWidth: CGFloat = 128

    let rows: [TimelineRow]
    let start: Date
    let hours: Int
    let cursor: Date
    @Binding var position: ScrollPosition
    let isEditing: Bool
    let onScroll: (CGFloat) -> Void
    let onRemove: (WorldCity) -> Void
    let onMove: (_ id: String, _ targetID: String) -> Void
    @State private var dropTarget: String?

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                ForEach(rows) { row in
                    CursorLabel(row: row, cursor: cursor)
                        .frame(height: Self.rowHeight)
                        .background(dropTarget == row.id ? Color.accentColor.opacity(0.15) : .clear)
                        .overlay(alignment: .topTrailing) {
                            if isEditing && !row.isLocal {
                                Button("Remove \(row.city.name)", systemImage: "minus.circle.fill", role: .destructive) {
                                    onRemove(row.city)
                                }
                                .labelStyle(.iconOnly)
                                .foregroundStyle(.white, .red)
                                .font(.title3)
                                .padding(4)
                            }
                        }
                        .overlay(alignment: .bottomTrailing) {
                            if isEditing {
                                Image(systemName: "line.3.horizontal")
                                    .foregroundStyle(.secondary)
                                    .padding(6)
                            }
                        }
                        .contentShape(Rectangle())
                        .draggable(row.id) { CursorLabel(row: row, cursor: cursor).frame(width: Self.labelWidth, height: Self.rowHeight) }
                        .dropDestination(for: String.self) { ids, _ in
                            guard let id = ids.first, id != row.id else { return false }
                            withAnimation { onMove(id, row.id) }
                            return true
                        } isTargeted: { dropTarget = $0 ? row.id : (dropTarget == row.id ? nil : dropTarget) }
                        .contextMenu {
                            if !row.isLocal {
                                Button("Remove", systemImage: "trash", role: .destructive) { onRemove(row.city) }
                            }
                        }
                    Divider()
                }
            }
            .frame(width: Self.labelWidth)

            GeometryReader { geo in
                let half = geo.size.width / 2
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        Color.clear.frame(width: half)
                        strips
                        Color.clear.frame(width: half)
                    }
                }
                .scrollPosition($position)
                .scrollTargetBehavior(QuarterHourSnap(step: Self.cellWidth / 4))
                .onScrollGeometryChange(for: CGFloat.self, of: \.contentOffset.x) { onScroll($1) }
                .overlay { cursorLine }
            }
        }
        .frame(height: (Self.rowHeight + 1) * CGFloat(rows.count))
    }

    private var strips: some View {
        VStack(spacing: 0) {
            ForEach(rows) { row in
                LazyHStack(spacing: 0) {
                    ForEach(0..<hours, id: \.self) { i in
                        HourCell(date: start.addingTimeInterval(Double(i) * 3600), calendar: row.calendar)
                            .frame(width: Self.cellWidth, height: Self.rowHeight)
                    }
                }
                Divider()
            }
        }
        .overlay(alignment: .leading) { nowMarker }
    }

    private var nowMarker: some View {
        TimelineView(.everyMinute) { context in
            Rectangle()
                .fill(.red)
                .frame(width: 1.5)
                .offset(x: CGFloat(context.date.timeIntervalSince(start) / 3600) * Self.cellWidth)
        }
        .allowsHitTesting(false)
    }

    private var cursorLine: some View {
        Rectangle()
            .fill(.tint)
            .frame(width: 2)
            .overlay(alignment: .top) {
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.tint)
                    .offset(y: -8)
            }
            .allowsHitTesting(false)
    }
}

struct QuarterHourSnap: ScrollTargetBehavior {
    let step: CGFloat

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        target.rect.origin.x = (target.rect.origin.x / step).rounded() * step
    }
}

private struct CursorLabel: View {
    let row: TimelineRow
    let cursor: Date

    var body: some View {
        let tz = row.city.timeZone
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                if row.isLocal { Image(systemName: "house.fill").font(.caption2) }
                Text(row.city.name).font(.subheadline.weight(.semibold)).lineLimit(1)
            }
            Text(cursor.formatted(Date.FormatStyle(timeZone: tz).hour().minute()))
                .font(.title3.monospacedDigit())
            Text([cursor.formatted(Date.FormatStyle(timeZone: tz).weekday(.abbreviated).month(.abbreviated).day()),
                  row.city.offsetLabel(at: cursor)].filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
    }
}

private struct HourCell: View {
    let date: Date
    let calendar: Calendar

    private static let uses12h = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .current)?.contains("a") ?? false

    var body: some View {
        let parts = calendar.dateComponents([.month, .day, .hour, .minute], from: date)
        let hour = parts.hour ?? 0, minute = parts.minute ?? 0
        VStack(spacing: 0) {
            if hour == 0 {
                Text(calendar.shortMonthSymbols[(parts.month ?? 1) - 1]).font(.system(size: 9).weight(.semibold))
                Text("\(parts.day ?? 1)").font(.callout.weight(.bold))
            } else {
                Text(label(hour: hour, minute: minute)).font(.callout.monospacedDigit())
                if Self.uses12h {
                    Text(hour < 12 ? "am" : "pm").font(.system(size: 9)).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(hour == 0 ? Color.primary.opacity(0.12) : HourShade(hour: hour).color)
        .overlay(alignment: .leading) { Rectangle().fill(.background).frame(width: 0.5) }
    }

    private func label(hour: Int, minute: Int) -> String {
        let h = Self.uses12h ? (hour % 12 == 0 ? 12 : hour % 12) : hour
        return minute == 0 ? "\(h)" : "\(h):\(String(format: "%02d", minute))"
    }
}
