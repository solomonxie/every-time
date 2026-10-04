import SwiftUI

/// Today on a clock face, midnight on top: each range an arc in its activity's colour, a tick where it started;
/// the hours still to come are blank, with plans drawn faint. Tap or drag on the track to put the cursor at any
/// time today — ahead of now, a tag then becomes a plan. Long-press a tick for its pin's options. ‹ › step back a day.
struct ActivityRing: View {
    let spans: [ActivitySpan]
    /// Coffee and feelings: a dot on the track, on top of whatever was going on.
    var moments: [ActivityMark] = []
    /// Pins ahead of now, drawn faint in the blank part.
    var planned: [ActivitySpan] = []
    /// Earliest time you can step back to.
    let start: Date
    let now: Date
    let selected: UUID?
    /// Coffee cutoff to bedtime, drawn as a red band just inside the track.
    var noCoffee: DateInterval? = nil
    /// Today, the cursor may go ahead of now (to plan).
    var allowsFuture = true
    /// Where the cursor settled; nil while following now.
    @Binding var cursor: Date?
    /// Jumps here when set, e.g. a range picked from History.
    @Binding var focus: Date?
    let onHoldPin: (UUID) -> Void

    /// Days back from today.
    @State private var offset = 0
    @State private var isDragging = false
    @State private var holding = false

    static let snap: TimeInterval = 5 * 60
    private static let day: TimeInterval = 86_400

    /// Midnight to midnight.
    private var window: DateInterval {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let dayStart = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(Self.day)
        return DateInterval(start: dayStart, end: dayEnd)
    }

    private var canStepBack: Bool { window.start > start }

    var body: some View {
        let window = window
        VStack(spacing: 10) {
            ZStack {
                GeometryReader { geo in
                    let side = min(geo.size.width, geo.size.height)
                    let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                    let track = side * 0.17
                    let radius = (side - track) / 2 - 12
                    Canvas { context, _ in
                        draw(&context, center: center, radius: radius, track: track, window: window)
                    }
                    .contentShape(Rectangle())
                    .gesture(drag(center: center, radius: radius, track: track, window: window))
                    .simultaneousGesture(tap(center: center, radius: radius, track: track, window: window))
                    .simultaneousGesture(hold(center: center, radius: radius, track: track, window: window))
                }
                .aspectRatio(1, contentMode: .fit)
                centre(window: window)
            }
            .sensoryFeedback(.selection, trigger: cursor)
            .onChange(of: focus) {
                guard let focus else { return }
                let calendar = Calendar.current
                offset = max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: focus), to: calendar.startOfDay(for: now)).day ?? 0)
                cursor = focus
                self.focus = nil
            }
            .accessibilityElement()
            .accessibilityLabel("Timeline at \(SleepNow.clock(cursor ?? now))")
            dayStepper(window: window)
        }
    }

    // MARK: Centre

    /// The cursor's time and what was (or is planned to be) going on then.
    private func centre(window: DateInterval) -> some View {
        let at = cursor ?? (offset == 0 ? now : window.end)
        let isAhead = at > now
        let span = (isAhead ? planned : spans).last { $0.start <= at && $0.end >= at }
        return VStack(spacing: 4) {
            Text(cursor == nil && offset == 0 ? "Now" : SleepNow.clock(at))
                .font(.clock(26, weight: .semibold))
                .contentTransition(.numericText())
            if isAhead, span == nil {
                Text("Tap a tag to plan").font(.caption).foregroundStyle(.secondary)
            } else if let span {
                Label(span.tag == nil ? "Untagged" : span.activity.title, systemImage: span.activity.symbol)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(span.tag == nil ? .secondary : span.activity.tint)
                    .lineLimit(1)
                Text(isAhead ? "planned for \(SleepNow.clock(span.start))"
                     : "since \(SleepNow.clock(span.start)) · \(ActivityLog.duration(min(at, span.end).timeIntervalSince(span.start)))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else {
                Text("Nothing marked").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 44)
        .allowsHitTesting(false)
        .animation(.snappy(duration: 0.15), value: at)
    }

    private func dayStepper(window: DateInterval) -> some View {
        HStack(spacing: 14) {
            Button("Earlier", systemImage: "chevron.left") { withAnimation(.snappy) { offset += 1; cursor = nil } }
                .disabled(!canStepBack)
            Text(offset == 0 ? "Today" : offset == 1 ? "Yesterday" : window.start.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(.label)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
            Button("Later", systemImage: "chevron.right") { withAnimation(.snappy) { offset -= 1; cursor = nil } }
                .disabled(offset == 0)
        }
        .labelStyle(.iconOnly)
        .font(.body.weight(.semibold))
        .buttonStyle(.borderless)
    }

    // MARK: Drawing

    private func draw(_ context: inout GraphicsContext, center: CGPoint, radius: CGFloat, track: CGFloat, window: DateInterval) {
        context.stroke(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                       with: .color(.primary.opacity(0.08)), lineWidth: track)
        // Today: the hours still to come are blank, with plans drawn faint.
        if offset == 0, fraction(now) < 0.995 {
            let ahead = fraction(now)
            context.stroke(arc(ahead, 1, center: center, radius: radius), with: .color(Color(.systemBackground).opacity(0.7)),
                           style: StrokeStyle(lineWidth: track - 2, lineCap: .butt))
            for plan in planned where plan.start < window.end {
                let from = max(plan.start, now), to = min(plan.end, window.end)
                let color = plan.activity.tint.opacity(0.3)
                if to > from {
                    for (a, b) in Self.pieces(fraction(from), fraction(to)) {
                        context.stroke(arc(a, b, center: center, radius: radius), with: .color(color),
                                       style: StrokeStyle(lineWidth: track - 6, lineCap: .butt, dash: [6, 4]))
                    }
                }
                if plan.activity.isMoment {
                    let at = point(fraction(plan.start), radius: radius, center: center)
                    let dot = track * 0.6
                    context.stroke(Path(ellipseIn: CGRect(x: at.x - dot / 2, y: at.y - dot / 2, width: dot, height: dot)),
                                   with: .color(plan.activity.tint.opacity(0.7)), style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
                }
                if plan.tag != nil {
                    context.draw(Text(Image(systemName: plan.activity.symbol)).font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(plan.activity.tint.opacity(0.9)), at: point(fraction(plan.start), radius: radius, center: center))
                }
                tick(&context, at: fraction(plan.start), center: center, radius: radius, track: track, color: plan.activity.tint.opacity(0.7))
            }
        }
        let inner = radius - track / 2 - 6
        context.fill(Path(ellipseIn: CGRect(x: center.x - inner, y: center.y - inner, width: inner * 2, height: inner * 2)),
                     with: .color(Theme.cardFill))
        face(&context, center: center, radius: radius - track / 2 - 14)
        if let noCoffee { coffeeBand(&context, noCoffee, center: center, radius: radius - track / 2 - 3) }

        let shown = offset == 0 ? min(now, window.end) : window.end
        let visible = spans.filter { $0.end > window.start && $0.start < shown }
        // Overlapping stretches (feelings) share the track in lanes, outermost first.
        let lanes = Self.lanes(visible)
        let laneCount = max(1, (lanes.values.max() ?? 0) + 1)
        let laneWidth = (track - 6) / CGFloat(laneCount)
        for span in visible {
            let from = max(span.start, window.start), to = min(span.end, shown)
            let color = span.activity.tint.opacity(span.tag == nil ? 0.22 : 0.6)
            let lane = lanes[span.id] ?? 0
            let r = laneCount == 1 ? radius : radius + (track - 6) / 2 - laneWidth * (CGFloat(lane) + 0.5)
            for (a, b) in Self.pieces(fraction(from), fraction(to)) {
                let path = arc(a, b, center: center, radius: r)
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: laneWidth, lineCap: .butt))
                if span.id == selected {
                    context.stroke(path, with: .color(.primary), style: StrokeStyle(lineWidth: laneWidth, lineCap: .butt))
                    context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: max(2, laneWidth - 4), lineCap: .butt))
                }
            }
            let length = to.timeIntervalSince(from) / Self.day * 2 * .pi * r
            if length > 30, span.tag != nil, laneWidth >= 14 {
                let mid = from.addingTimeInterval(to.timeIntervalSince(from) / 2)
                context.draw(Text(Image(systemName: span.activity.symbol)).font(.system(size: min(11, laneWidth * 0.7), weight: .semibold)),
                             at: point(fraction(mid), radius: r, center: center))
            }
            if span.start >= window.start {
                tick(&context, at: fraction(span.start), center: center, radius: radius, track: track, color: .primary.opacity(0.8))
            }
        }

        for mark in moments where window.contains(mark.time) {
            let activity = Activity.of(mark.tag)
            let at = point(fraction(mark.time), radius: radius, center: center)
            let dot = track * 0.6
            context.fill(Path(ellipseIn: CGRect(x: at.x - dot / 2, y: at.y - dot / 2, width: dot, height: dot)), with: .color(activity.tint))
            context.stroke(Path(ellipseIn: CGRect(x: at.x - dot / 2, y: at.y - dot / 2, width: dot, height: dot)),
                           with: .color(Color(.systemBackground)), lineWidth: 2)
            context.draw(Text(Image(systemName: activity.symbol)).font(.system(size: 10, weight: .semibold)).foregroundStyle(.white), at: at)
        }

        if offset == 0 {
            tick(&context, at: fraction(now), center: center, radius: radius, track: track + 6, color: Theme.Tone.bad, width: 3)
        }
        if let cursor, window.contains(cursor) {
            tick(&context, at: fraction(cursor), center: center, radius: radius, track: track + 14, color: .accentColor, width: 3)
            let knob = point(fraction(cursor), radius: radius + track / 2 + 10, center: center)
            context.fill(Path(ellipseIn: CGRect(x: knob.x - 6, y: knob.y - 6, width: 12, height: 12)), with: .color(.accentColor))
        }
    }

    private func coffeeBand(_ context: inout GraphicsContext, _ band: DateInterval, center: CGPoint, radius: CGFloat) {
        let red = Color.red.opacity(0.9)
        for (a, b) in Self.pieces(fraction(band.start), fraction(band.end)) {
            context.stroke(arc(a, b, center: center, radius: radius), with: .color(red), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
        let mid = band.start.addingTimeInterval(band.duration / 2)
        let at = point(fraction(mid), radius: radius - 12, center: center)
        context.draw(Text(Image(systemName: "cup.and.saucer.fill")).font(.system(size: 12)).foregroundStyle(red), at: at)
        var slash = Path()
        slash.move(to: CGPoint(x: at.x - 6, y: at.y + 6))
        slash.addLine(to: CGPoint(x: at.x + 6, y: at.y - 6))
        context.stroke(slash, with: .color(.red), style: StrokeStyle(lineWidth: 2, lineCap: .round))
    }

    private func face(_ context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        for hour in 0..<24 {
            let f = Double(hour) / 24
            let isMajor = hour % 3 == 0
            let outer = point(f, radius: radius, center: center), innerPoint = point(f, radius: radius - (isMajor ? 8 : 5), center: center)
            var path = Path()
            path.move(to: outer)
            path.addLine(to: innerPoint)
            context.stroke(path, with: .color(.primary.opacity(isMajor ? 0.35 : 0.15)), lineWidth: isMajor ? 2 : 1.5)
            if isMajor {
                let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: now) ?? now
                context.draw(Text(date.formatted(.dateTime.hour())).font(.caption2.weight(.medium)).foregroundStyle(.secondary),
                             at: point(f, radius: radius - 18, center: center))
            }
        }
    }

    private func tick(_ context: inout GraphicsContext, at f: Double, center: CGPoint, radius: CGFloat, track: CGFloat,
                      color: Color, width: CGFloat = 2) {
        var path = Path()
        path.move(to: point(f, radius: radius - track / 2, center: center))
        path.addLine(to: point(f, radius: radius + track / 2, center: center))
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
    }

    private func arc(_ from: Double, _ to: Double, center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        path.addArc(center: center, radius: radius, startAngle: .degrees(from * 360 - 90), endAngle: .degrees(to * 360 - 90), clockwise: false)
        return path
    }

    /// Lane per stretch so overlapping ones sit side by side; stretches that don't overlap share lane 0.
    static func lanes(_ spans: [ActivitySpan]) -> [UUID: Int] {
        var ends: [Date] = []
        var lanes: [UUID: Int] = [:]
        for span in spans.sorted(by: { $0.start < $1.start }) {
            if let free = ends.firstIndex(where: { $0 <= span.start }) {
                ends[free] = span.end
                lanes[span.id] = free
            } else {
                ends.append(span.end)
                lanes[span.id] = ends.count - 1
            }
        }
        return lanes
    }

    /// An arc that crosses midnight is drawn as two.
    static func pieces(_ from: Double, _ to: Double) -> [(Double, Double)] {
        to >= from ? [(from, to)] : [(from, 1), (0, to)]
    }

    // MARK: Gestures

    private func drag(center: CGPoint, radius: CGFloat, track: CGFloat, window: DateInterval) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                if !isDragging {
                    let distance = hypot(value.startLocation.x - center.x, value.startLocation.y - center.y)
                    guard abs(distance - radius) < track / 2 + 24 else { return }
                    isDragging = true
                }
                let time = time(at: value.location, center: center, window: window)
                cursor = offset == 0 && abs(now.timeIntervalSince(time)) < Self.snap / 2 ? nil : time
            }
            .onEnded { _ in isDragging = false }
    }

    /// A tap on the track puts the cursor there; off the track, back on now.
    private func tap(center: CGPoint, radius: CGFloat, track: CGFloat, window: DateInterval) -> some Gesture {
        SpatialTapGesture().onEnded { value in
            let distance = hypot(value.location.x - center.x, value.location.y - center.y)
            guard abs(distance - radius) < track / 2 + 24 else { cursor = nil; return }
            let time = time(at: value.location, center: center, window: window)
            cursor = offset == 0 && abs(now.timeIntervalSince(time)) < Self.snap / 2 ? nil : time
        }
    }

    private func hold(center: CGPoint, radius: CGFloat, track: CGFloat, window: DateInterval) -> some Gesture {
        LongPressGesture(minimumDuration: 0.5)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                guard case .second(true, let touch?) = value, !holding else { return }
                holding = true
                let distance = hypot(touch.location.x - center.x, touch.location.y - center.y)
                guard abs(distance - radius) < track / 2 + 24 else { return }
                let time = time(at: touch.location, center: center, window: window, snapped: false)
                let tolerance = 20 / (2 * .pi * radius) * Self.day
                let pins = spans.filter { window.contains($0.start) }.map { ($0.id, $0.start) }
                    + moments.filter { window.contains($0.time) }.map { ($0.id, $0.time) }
                    + planned.filter { window.contains($0.start) }.map { ($0.id, $0.start) }
                if let pin = pins.map({ ($0.0, abs($0.1.timeIntervalSince(time))) })
                    .filter({ $0.1 <= tolerance }).min(by: { $0.1 < $1.1 })?.0 {
                    onHoldPin(pin)
                }
            }
            .onEnded { _ in holding = false }
    }

    // MARK: Geometry

    /// Fraction of the clock face, midnight = 0.
    private func fraction(_ date: Date) -> Double {
        let start = Calendar.current.startOfDay(for: date)
        return date.timeIntervalSince(start) / Self.day
    }

    private func point(_ f: Double, radius: CGFloat, center: CGPoint) -> CGPoint {
        let angle = f * 2 * .pi
        return CGPoint(x: center.x + radius * sin(angle), y: center.y - radius * cos(angle))
    }

    /// The time in the window at the touch's clock position; today it may be ahead of now (a plan).
    private func time(at location: CGPoint, center: CGPoint, window: DateInterval, snapped: Bool = true) -> Date {
        var angle = atan2(location.x - center.x, center.y - location.y)
        if angle < 0 { angle += 2 * .pi }
        let f = angle / (2 * .pi)
        var ahead = (f - fraction(window.start)) * Self.day
        if ahead < 0 { ahead += Self.day }
        var time = window.start.addingTimeInterval(ahead)
        if snapped { time = Date(timeIntervalSinceReferenceDate: (time.timeIntervalSinceReferenceDate / Self.snap).rounded() * Self.snap) }
        let latest = allowsFuture ? window.end.addingTimeInterval(-Self.snap) : now
        return min(latest, max(window.start, time))
    }
}
