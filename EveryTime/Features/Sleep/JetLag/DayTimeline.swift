import SwiftUI

/// A plan day as drawn. Eastbound the next day's midnight comes before this day ends, so its
/// band starts at `lower`; westbound the gap until the next midnight becomes a continuation band.
struct DayWindow: Identifiable {
    let day: PlanDay
    let start: Date
    let lower: Date
    let end: Date
    let actions: [PlanAction]
    var isContinuation: Bool { start != day.start }
    var id: Date { start }
    var timeZone: TimeZone { day.timeZone }

    static func windows(for plan: JetLagPlan) -> [DayWindow] {
        let all = plan.actions
        var result: [DayWindow] = []
        func add(_ day: PlanDay, start: Date, end: Date) {
            let lower = max(start, result.last?.end ?? start)
            let actions = all.filter { $0.start < end && ($0.end > lower || ($0.start == $0.end && $0.start >= lower)) }
            result.append(DayWindow(day: day, start: start, lower: lower, end: end, actions: actions))
        }
        for (i, day) in plan.days.enumerated() {
            add(day, start: day.start, end: day.end)
            if i + 1 < plan.days.count, plan.days[i + 1].start > day.end {
                add(day, start: day.end, end: plan.days[i + 1].start)
            }
        }
        return result
    }
}

/// One day of the plan: hour axis in the day's time zone, a capsule column per category.
struct DayTimeline: View {
    static let nowID = "jetlag.now"
    private static let hourHeight: CGFloat = 30
    private static let axisWidth: CGFloat = 44

    let window: DayWindow

    var body: some View {
        let end = window.end
        let hours = (end.timeIntervalSince(window.start) / 3600).rounded(.up)
        let height = CGFloat(hours) * Self.hourHeight

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Color.clear.frame(width: Self.axisWidth, height: 1)
                ForEach(TimelineColumn.allCases, id: \.self) { column in
                    Text(column.title)
                        .font(.label)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(width: column == .melatonin ? 28 : nil)
                        .frame(maxWidth: column == .melatonin ? nil : .infinity)
                }
            }
            HStack(alignment: .top, spacing: 6) {
                axis(hours: Int(hours))
                ZStack(alignment: .topLeading) {
                    gridLines(hours: Int(hours))
                    Rectangle()
                        .fill(Theme.cardFill)
                        .frame(height: y(window.lower, height))
                    ForEach(window.actions.filter { $0.kind == .flight }) { flight in
                        FlightBand(action: flight, timeZone: window.timeZone)
                            .frame(height: y(flight.end, height) - y(flight.start, height))
                            .offset(y: y(flight.start, height))
                    }
                    HStack(spacing: 6) {
                        ForEach(TimelineColumn.allCases, id: \.self) { column in
                            columnView(column, height: height)
                        }
                    }
                    nowLine(end: end, height: height)
                }
                .frame(height: height, alignment: .top)
            }
        }
    }

    private func y(_ date: Date, _ height: CGFloat) -> CGFloat {
        let top = CGFloat(window.lower.timeIntervalSince(window.start) / 3600) * Self.hourHeight
        return min(max(CGFloat(date.timeIntervalSince(window.start) / 3600) * Self.hourHeight, top), height)
    }

    private func axis(hours: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            ForEach(0..<hours, id: \.self) { hour in
                Text(window.start.addingTimeInterval(Double(hour) * 3600).formatted(.dateTime.hour(), in: window.timeZone))
                    .font(.clock(10, weight: .regular))
                    .foregroundStyle(.secondary)
                    .offset(y: CGFloat(hour) * Self.hourHeight - 6)
            }
        }
        .frame(width: Self.axisWidth, alignment: .topTrailing)
        .accessibilityHidden(true)
    }

    private func gridLines(hours: Int) -> some View {
        Path { path in
            for hour in 0...hours {
                let y = CGFloat(hour) * Self.hourHeight
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: 2000, y: y))
            }
        }
        .stroke(Theme.hairline, lineWidth: 1)
        .clipped()
    }

    private func columnView(_ column: TimelineColumn, height: CGFloat) -> some View {
        ZStack(alignment: .top) {
            ForEach(window.actions.filter { $0.kind.column == column }) { action in
                let top = y(action.start, height)
                ActionBar(action: action, timeZone: window.timeZone, height: y(action.end, height) - top)
                    .offset(y: top)
            }
        }
        .frame(width: column == .melatonin ? 28 : nil)
        .frame(maxWidth: column == .melatonin ? nil : .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func nowLine(end: Date, height: CGFloat) -> some View {
        TimelineView(.everyMinute) { context in
            if context.date >= window.lower, context.date < end {
                HStack(spacing: 0) {
                    Circle().frame(width: 8, height: 8)
                    Rectangle().frame(height: 1.5)
                }
                .foregroundStyle(Theme.Tone.bad)
                .offset(x: -4, y: y(context.date, height) - 4)
                .id(Self.nowID)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
    }
}

private struct ActionBar: View {
    let action: PlanAction
    let timeZone: TimeZone
    let height: CGFloat
    @State private var showsDetail = false

    var body: some View {
        Button { showsDetail = true } label: {
            if action.kind == .melatonin {
                Image(systemName: action.kind.symbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(action.kind.color, in: Circle())
                    .offset(y: -12)
            } else {
                ActionCapsule(kind: action.kind)
                    .overlay(alignment: .top) {
                        ActionIcon(kind: action.kind)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(action.kind.iconColor)
                            .padding(.top, 6)
                    }
                    .frame(width: 30, height: max(height, 26))
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showsDetail) { ActionDetail(action: action, timeZone: timeZone) }
        .accessibilityLabel("\(action.kind.title), \(action.timeRange(in: timeZone))")
    }
}

private struct FlightBand: View {
    let action: PlanAction
    let timeZone: TimeZone
    @State private var showsDetail = false

    var body: some View {
        Button { showsDetail = true } label: {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.07))
                .overlay(alignment: .topLeading) {
                    Image(systemName: "airplane")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(6)
                }
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showsDetail) { ActionDetail(action: action, timeZone: timeZone) }
        .accessibilityLabel("Flight, \(action.timeRange(in: timeZone))")
    }
}
