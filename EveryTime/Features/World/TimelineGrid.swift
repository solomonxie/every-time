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
        case .night: Theme.Tone.night
        case .edge: Theme.Tone.edge
        case .work: Theme.Tone.work
        }
    }
}

/// World Time Buddy–style grid: pinned city labels, hour strips sharing one horizontal scroll,
/// a fixed center cursor whose instant drives every label.
struct TimelineGrid: View {
    static let cellWidth: CGFloat = 40
    static let rowHeight: CGFloat = 56
    static let rowGap: CGFloat = 6
    static let labelWidth: CGFloat = 156
    static let topInset: CGFloat = 28

    let rows: [TimelineRow]
    let start: Date
    let hours: Int
    let cursor: Date
    @Binding var position: ScrollPosition
    let isEditing: Bool
    let snaps: Bool
    let onScroll: (CGFloat) -> Void
    let onDragStart: () -> Void
    let onRemove: (WorldCity) -> Void
    let onMove: (_ id: String, _ targetID: String) -> Void
    @State private var dropTarget: String?

    private var stripsHeight: CGFloat {
        CGFloat(rows.count) * Self.rowHeight + CGFloat(max(rows.count - 1, 0)) * Self.rowGap
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: Self.rowGap) {
                ForEach(rows) { row in label(row) }
            }
            .padding(.top, Self.topInset)
            .padding(.leading, Theme.padding - 8)
            .frame(width: Self.labelWidth)

            GeometryReader { geo in
                let half = geo.size.width / 2
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        Color.clear.frame(width: half)
                        strips.padding(.top, Self.topInset)
                        Color.clear.frame(width: half)
                    }
                }
                .scrollPosition($position)
                .scrollTargetBehavior(QuarterHourSnap(step: snaps ? Self.cellWidth / 4 : 0))
                .onScrollGeometryChange(for: CGFloat.self, of: \.contentOffset.x) { onScroll($1) }
                .onScrollPhaseChange { _, phase in
                    if phase == .interacting { onDragStart() }
                }
                .mask {
                    LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.05),
                                           .init(color: .black, location: 0.95), .init(color: .clear, location: 1)],
                                   startPoint: .leading, endPoint: .trailing)
                }
                .overlay { cursorLine }
            }
        }
        .frame(height: Self.topInset + stripsHeight)
    }

    private func label(_ row: TimelineRow) -> some View {
        CursorLabel(row: row, cursor: cursor, isEditing: isEditing) { onRemove(row.city) }
            .frame(height: Self.rowHeight)
            .background(dropTarget == row.id ? Color.accentColor.opacity(0.12) : .clear,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(Rectangle())
            .draggable(row.id) {
                CursorLabel(row: row, cursor: cursor, isEditing: false) {}
                    .frame(width: Self.labelWidth, height: Self.rowHeight)
            }
            .dropDestination(for: String.self) { ids, _ in
                guard let id = ids.first, id != row.id else { return false }
                withAnimation(.snappy) { onMove(id, row.id) }
                return true
            } isTargeted: { dropTarget = $0 ? row.id : (dropTarget == row.id ? nil : dropTarget) }
            .contextMenu {
                if !row.isLocal {
                    Button("Remove", systemImage: "trash", role: .destructive) { onRemove(row.city) }
                }
            }
    }

    private var strips: some View {
        VStack(spacing: Self.rowGap) {
            ForEach(rows) { row in
                LazyHStack(spacing: 0) {
                    ForEach(0..<hours, id: \.self) { i in
                        HourCell(date: start.addingTimeInterval(Double(i) * 3600), calendar: row.calendar)
                            .frame(width: Self.cellWidth, height: Self.rowHeight)
                    }
                }
            }
        }
        .overlay(alignment: .leading) { nowMarker }
    }

    private var nowMarker: some View {
        TimelineView(.everyMinute) { context in
            Rectangle()
                .fill(Theme.Tone.bad)
                .frame(width: 1)
                .offset(x: CGFloat(context.date.timeIntervalSince(start) / 3600) * Self.cellWidth)
        }
        .allowsHitTesting(false)
    }

    private var cursorLine: some View {
        VStack(spacing: 0) {
            Text(cursor.formatted(.dateTime.hour().minute()))
                .font(.clock(12, weight: .semibold))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .padding(.horizontal, 8)
                .frame(height: 20)
                .background(Color.accentColor, in: Capsule())
                .fixedSize()
            Rectangle().fill(.tint).frame(width: 1.5)
        }
        .allowsHitTesting(false)
    }
}

struct QuarterHourSnap: ScrollTargetBehavior {
    let step: CGFloat

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        guard step > 0 else { return }
        target.rect.origin.x = (target.rect.origin.x / step).rounded() * step
    }
}

private struct CursorLabel: View {
    let row: TimelineRow
    let cursor: Date
    let isEditing: Bool
    let onRemove: () -> Void

    var body: some View {
        let tz = row.city.timeZone
        HStack(spacing: 8) {
            if isEditing && !row.isLocal {
                Button("Remove \(row.city.name)", systemImage: "minus.circle.fill", role: .destructive, action: onRemove)
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.white, Theme.Tone.bad)
                    .font(.title3)
                    .transition(.scale.combined(with: .opacity))
            }
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    if row.isLocal {
                        Image(systemName: "house.fill").font(.caption2).foregroundStyle(.secondary)
                    }
                    Text(row.city.name).font(.cardTitle).lineLimit(1).minimumScaleFactor(0.75)
                }
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(cursor.formatted(Date.FormatStyle(timeZone: tz).hour().minute()))
                        .font(.clock(22))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .contentTransition(.numericText())
                    Text(secondary(tz))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if isEditing {
                Image(systemName: "line.3.horizontal").foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 8)
    }

    /// Offset, prefixed with the weekday when the city is on another day.
    private func secondary(_ tz: TimeZone) -> String {
        let day = cursor.formatted(Date.FormatStyle(timeZone: tz).weekday(.abbreviated))
        let localDay = cursor.formatted(Date.FormatStyle().weekday(.abbreviated))
        return [day == localDay ? nil : day, row.city.offsetLabel(at: cursor)]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

/// One hour; consecutive hours of the same shade merge into a rounded band.
private struct HourCell: View {
    let date: Date
    let calendar: Calendar

    private static let uses12h = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .current)?.contains("a") ?? false
    private static let radius: CGFloat = 12

    var body: some View {
        let parts = calendar.dateComponents([.weekday, .day, .hour, .minute], from: date)
        let hour = parts.hour ?? 0, minute = parts.minute ?? 0
        let prev = calendar.component(.hour, from: date.addingTimeInterval(-3600))
        let next = calendar.component(.hour, from: date.addingTimeInterval(3600))
        let opensBand = band(prev) != band(hour), closesBand = band(next) != band(hour)

        VStack(spacing: 1) {
            if hour == 0 {
                Text(calendar.shortWeekdaySymbols[(parts.weekday ?? 1) - 1])
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                Text("\(parts.day ?? 1)").font(.system(size: 14, weight: .semibold, design: .rounded))
            } else {
                Text(label(hour: hour, minute: minute))
                    .font(.system(size: minute == 0 ? 13 : 11, design: .rounded).monospacedDigit())
                    .foregroundStyle(.primary.opacity(0.75))
                if Self.uses12h {
                    Text(hour < 12 ? "am" : "pm")
                        .font(.system(size: 8, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            hour == 0 ? Theme.cardFill : HourShade(hour: hour).color,
            in: UnevenRoundedRectangle(
                topLeadingRadius: opensBand ? Self.radius : 0, bottomLeadingRadius: opensBand ? Self.radius : 0,
                bottomTrailingRadius: closesBand ? Self.radius : 0, topTrailingRadius: closesBand ? Self.radius : 0,
                style: .continuous)
        )
        .padding(.leading, opensBand ? 1.5 : 0)
        .padding(.trailing, closesBand ? 1.5 : 0)
    }

    /// nil = midnight cell, its own band.
    private func band(_ hour: Int) -> HourShade? {
        hour == 0 ? nil : HourShade(hour: hour)
    }

    private func label(hour: Int, minute: Int) -> String {
        let h = Self.uses12h ? (hour % 12 == 0 ? 12 : hour % 12) : hour
        return minute == 0 ? "\(h)" : "\(h):\(String(format: "%02d", minute))"
    }
}
