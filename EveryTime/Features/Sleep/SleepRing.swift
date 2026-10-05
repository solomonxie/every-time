import SwiftUI

/// Where a wake lands in its cycle. Each cycle runs light (N1/N2) → deep (N3) → light → REM;
/// waking near a cycle's end is easy, waking in deep sleep is groggy. Deep sleep thins out after the first ~3 cycles.
enum WakeFit: Equatable {
    case good, okay, poor

    /// Deep sleep's share of a cycle, as a fraction of it (~25–65 min of 90).
    static let deep = 0.28...0.72

    static func of(length: TimeInterval, fallAsleep: TimeInterval = SleepSuggestion.fallAsleepTime,
                   cycle: TimeInterval = SleepSuggestion.cycleLength) -> WakeFit {
        let asleep = max(0, length - fallAsleep) / cycle
        let done = Int(asleep), phase = asleep - Double(done)
        if phase >= 0.85 || phase <= 0.12 { return .good }
        if deep.contains(phase) { return done >= 3 ? .okay : .poor }
        return .okay
    }

    /// Naps stay short of a full cycle: best before deep sleep starts, worst in the middle of it.
    static func nap(length: TimeInterval, fallAsleep: TimeInterval = SleepSuggestion.fallAsleepTime,
                    cycle: TimeInterval = SleepSuggestion.cycleLength) -> WakeFit {
        let phase = max(0, length - fallAsleep) / cycle
        if phase <= deep.lowerBound { return .good }
        return deep.contains(phase) ? .poor : .okay
    }

    /// Nights on whole cycles, naps before deep sleep.
    static func of(length: TimeInterval, isNap: Bool) -> WakeFit {
        isNap ? nap(length: length) : of(length: length)
    }

    func text(isNap: Bool) -> String {
        isNap && self == .good ? "Wakes before deep sleep" : text
    }

    var color: Color {
        switch self {
        case .good: Theme.Tone.good
        case .okay: .yellow
        case .poor: Theme.Tone.bad
        }
    }

    var text: String {
        switch self {
        case .good: "Wakes between cycles"
        case .okay: "Wakes in light sleep"
        case .poor: "Wakes in deep sleep"
        }
    }
}

/// A 24-hour clock face, midnight on top, with now pinned: the sleep runs from bed (now or later) to the alarm.
/// Idle, drag either handle (the alarm has detents at cycle ends); planned or asleep, it counts down.
struct SleepRing: View {
    let now: Date
    /// Idle: lying down, now or later.
    var bed: Binding<Date>? = nil
    /// Idle: the alarm.
    var wake: Binding<Date>? = nil
    /// Planned or asleep: the ring just counts down.
    var plan: ActiveNap? = nil
    /// Idle nap: one icon at now; its length (minutes) is set elsewhere.
    var nap: Int? = nil
    /// Shortest sleep the handles allow.
    var minLength = SleepRing.lengths.lowerBound

    private enum Handle: Equatable { case bed, alarm, whole(from: Int) }
    @State private var dragging: Handle?
    /// Bumps when a drag lands on a cycle end.
    @State private var detents = 0

    /// Bed and wake times move in 10-minute steps.
    static let step = 10
    private static let day = 24 * 60
    static let lengths = 10 ... 14 * 60

    private var isAsleep: Bool { plan.map { $0.start <= now } ?? false }

    /// The ring's top: now, floored to `step`.
    private var top: Date {
        let minutes = Int(now.timeIntervalSinceReferenceDate / 60)
        return Date(timeIntervalSinceReferenceDate: Double(minutes - minutes % Self.step) * 60)
    }

    /// Minutes from the top of the ring to lying down and to the alarm.
    private var start: Int {
        let start = plan.map { offset($0.start) } ?? bed.map { offset($0.wrappedValue) } ?? 0
        return min(Self.day, max(0, start))
    }
    private var end: Int {
        let end = plan.map { offset($0.alarm) } ?? nap.map { start + $0 } ?? wake.map { offset($0.wrappedValue) } ?? start + 8 * 60
        return min(Self.day, max(start, end))
    }

    private func offset(_ date: Date) -> Int { Int((date.timeIntervalSince(top) / 60).rounded()) }
    private func date(_ offset: Int) -> Date { top.addingTimeInterval(Double(offset) * 60) }

    private var length: TimeInterval { Double(end - start) * 60 }
    private var isNap: Bool { length < Nap.nightLength }
    private var fit: WakeFit { WakeFit.of(length: length, isNap: isNap) }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let track = side * 0.17
            let radius = (side - track) / 2 - 12
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let point = { (offset: Double, r: CGFloat) in self.point(offset, radius: r, center: center) }
            ZStack {
                Circle().stroke(Color.primary.opacity(0.08), lineWidth: track)
                    .frame(width: radius * 2, height: radius * 2).position(center)
                Circle().fill(Theme.cardFill).frame(width: (radius - track / 2 - 6) * 2, height: (radius - track / 2 - 6) * 2).position(center)
                face(radius: radius - track / 2 - 14, point: point)
                if nap == nil { cycles(radius: radius, track: track, center: center) }
                if let plan {
                    arc(start, end, color: .indigo.opacity(0.35), width: track - 6, radius: radius, center: center)
                    if isAsleep {
                        arc(start, min(end, max(start, offset(now))), color: .indigo, width: track - 6, radius: radius, center: center)
                    } else {
                        if !crowded(point, radius: radius, size: track - 14) {
                            marker("bed.double.fill", size: track - 14, tint: .indigo).position(point(Double(start), radius))
                        }
                    }
                    marker("alarm.fill", size: track - 14, tint: plan.ringsAlarm ? .indigo : .secondary)
                        .position(point(Double(end), radius))
                } else if nap != nil {
                    marker("cup.and.saucer.fill", size: track - 8, tint: fit.color).position(point(0, radius))
                } else {
                    arc(start, end, color: fit.color, width: track - 6, radius: radius, center: center)
                    if bed != nil, !crowded(point, radius: radius, size: track - 8) {
                        marker("bed.double.fill", size: track - 8, tint: .indigo, isGrabbed: dragging == .bed || isMovingWhole)
                            .position(point(Double(start), radius))
                    }
                    marker("alarm.fill", size: track - 8, tint: fit.color, isGrabbed: dragging == .alarm || isMovingWhole)
                        .position(point(Double(end), radius))
                }
                if nap == nil {
                    Capsule().fill(.primary).frame(width: 3, height: track + 6)
                        .rotationEffect(.degrees(degrees(0))).position(point(0, radius))
                }
                centre(side: side).position(center)
            }
            .contentShape(Band(radius: radius, width: track + 32), eoFill: true)
            .gesture(drag(center: center, radius: radius, track: track), including: plan == nil ? .all : .subviews)
        }
        .aspectRatio(1, contentMode: .fit)
        .sensoryFeedback(.selection, trigger: end)
        .sensoryFeedback(.impact(weight: .medium), trigger: detents)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sleep ring")
        .accessibilityValue("\(SleepNow.clock(date(start))) to \(SleepNow.clock(date(end))), \(fit.text(isNap: isNap))")
    }

    /// Only the ring's track takes touches, so the page scrolls from the space around and inside it.
    private struct Band: Shape {
        let radius: CGFloat
        let width: CGFloat

        func path(in rect: CGRect) -> Path {
            var path = Path()
            for r in [radius + width / 2, radius - width / 2] {
                path.addEllipse(in: CGRect(x: rect.midX - r, y: rect.midY - r, width: r * 2, height: r * 2))
            }
            return path
        }
    }

    // MARK: Parts

    /// A short nap puts both handles on top of each other; the alarm alone is drawn then.
    private func crowded(_ point: (Double, CGFloat) -> CGPoint, radius: CGFloat, size: CGFloat) -> Bool {
        Self.gap(point(Double(start), radius), point(Double(end), radius)) < size * 1.1
    }

    private func arc(_ from: Int, _ to: Int, color: Color, width: CGFloat, radius: CGFloat, center: CGPoint) -> some View {
        Circle()
            .trim(from: Double(from) / Double(Self.day), to: Double(to) / Double(Self.day))
            .stroke(color.gradient, style: StrokeStyle(lineWidth: width, lineCap: .round))
            .rotationEffect(.degrees(-90 + degrees(0)))
            .frame(width: radius * 2, height: radius * 2)
            .position(center)
    }

    /// From lying down on: each cycle's deep-sleep stretch shaded, a tick where it ends. Shown across the next 12 h.
    private func cycles(radius: CGFloat, track: CGFloat, center: CGPoint) -> some View {
        let fall = SleepSuggestion.fallAsleepTime / 60, cycle = SleepSuggestion.cycleLength / 60
        let origin = Double(start)
        let starts: [Double] = (0..<12).map { origin + fall + Double($0) * cycle }.filter { $0 < origin + 720 && $0 + cycle > 0 }
        return ZStack {
            ForEach(Array(starts.enumerated()), id: \.offset) { i, s in
                let from = max(0, min(Double(Self.day), s + cycle * WakeFit.deep.lowerBound))
                let to = max(0, min(Double(Self.day), s + cycle * WakeFit.deep.upperBound))
                Circle()
                    .trim(from: from / Double(Self.day), to: to / Double(Self.day))
                    .stroke(Color.indigo.opacity(i < 3 ? 0.45 : 0.2), lineWidth: track * 0.2)
                    .rotationEffect(.degrees(-90 + degrees(0)))
                    .frame(width: (radius + track * 0.38) * 2, height: (radius + track * 0.38) * 2)
                    .position(center)
                if s + cycle < Double(Self.day), s + cycle > 0 {
                    Capsule().fill(.primary.opacity(0.6))
                        .frame(width: 2, height: track * 0.24)
                        .rotationEffect(.degrees(degrees(s + cycle)))
                        .position(self.point(s + cycle, radius: radius + track * 0.38, center: center))
                }
            }
        }
    }

    /// Clock hours, placed relative to now.
    private func face(radius: CGFloat, point: @escaping (Double, CGFloat) -> CGPoint) -> some View {
        let shift = Self.wrap(-minutesOfDay(top))
        return ZStack {
            ForEach(0..<24, id: \.self) { hour in
                let offset = Double(Self.wrap(hour * 60 + shift))
                let isMajor = hour % 3 == 0
                Capsule()
                    .fill(Color.primary.opacity(isMajor ? 0.35 : 0.15))
                    .frame(width: isMajor ? 2 : 1.5, height: isMajor ? 8 : 5)
                    .rotationEffect(.degrees(degrees(offset)))
                    .position(point(offset, radius))
                if isMajor {
                    Text(Self.hourText(hour))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .position(point(offset, radius - 18))
                }
                if hour % 12 == 0 {
                    Image(systemName: hour == 0 ? "sparkles" : "sun.max.fill")
                        .foregroundStyle(hour == 0 ? Color.cyan : Color.yellow)
                        .position(point(offset, radius - 40))
                }
            }
        }
    }

    private func marker(_ symbol: String, size: CGFloat, tint: Color, isGrabbed: Bool = false) -> some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(tint, in: Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: 2))
            .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
            .scaleEffect(isGrabbed ? 1.2 : 1)
            .animation(.snappy(duration: 0.15), value: isGrabbed)
    }

    /// Idle: how long and how many cycles. Planned: until bed. Asleep: until the alarm.
    @ViewBuilder
    private func centre(side: CGFloat) -> some View {
        if plan != nil {
            EmptyView()
        } else {
            let cycles = max(0, length - SleepSuggestion.fallAsleepTime) / SleepSuggestion.cycleLength
            VStack(spacing: 2) {
                Text(ActivityLog.duration(length))
                    .font(.clock(side * 0.1, weight: .semibold))
                    .contentTransition(.numericText())
                Text(isNap ? "nap" : "\(cycles.formatted(.number.precision(.fractionLength(cycles.rounded() == cycles ? 0 : 1)))) cycles")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }
            .animation(.snappy(duration: 0.15), value: end)
        }
    }

    // MARK: Dragging

    private var isMovingWhole: Bool { if case .whole = dragging { true } else { false } }

    /// A handle moves its own end (the alarm snaps to cycle ends); the arc between them moves the whole range.
    /// The rest of the ring ignores touches.
    private func drag(center: CGPoint, radius: CGFloat, track: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard let wake else { return }
                if dragging == nil {
                    guard let grabbed = pick(value.startLocation, center: center, radius: radius, track: track) else { return }
                    dragging = grabbed
                }
                let offset = self.offset(at: value.location, center: center)
                switch dragging {
                case .bed:
                    // Past the ring's top counter-clockwise reads as "now".
                    let bedOffset = min(max(0, offset > end ? 0 : offset), end - minLength)
                    if bedOffset != start { bed?.wrappedValue = date(bedOffset) }
                case .alarm:
                    var alarm = min(max(offset, start + minLength), min(Self.day, start + Self.lengths.upperBound))
                    if let detent = Self.detent(near: alarm - start) {
                        if start + detent != end { detents += 1 }
                        alarm = start + detent
                    }
                    if alarm != end { wake.wrappedValue = date(alarm) }
                case .whole(let from):
                    let delta = Self.wrap(offset - from + Self.day / 2) - Self.day / 2
                    let length = end - start
                    let newStart = min(max(0, start + delta), Self.day - length)
                    guard newStart != start else { return }
                    bed?.wrappedValue = date(newStart)
                    wake.wrappedValue = date(newStart + length)
                    dragging = .whole(from: offset)
                case nil:
                    break
                }
            }
            .onEnded { _ in dragging = nil }
    }

    /// Nearest handle under the touch, else the arc.
    private func pick(_ location: CGPoint, center: CGPoint, radius: CGFloat, track: CGFloat) -> Handle? {
        let distance = hypot(location.x - center.x, location.y - center.y)
        guard abs(distance - radius) < track / 2 + 16 else { return nil }
        let toBed = bed == nil ? .infinity : Self.gap(location, point(Double(start), radius: radius, center: center))
        let toAlarm = Self.gap(location, point(Double(end), radius: radius, center: center))
        let reach = track * 0.9
        if min(toBed, toAlarm) < reach { return toBed < toAlarm ? .bed : .alarm }
        let offset = self.offset(at: location, center: center)
        return bed != nil && (start...end).contains(offset) ? .whole(from: offset) : nil
    }

    /// `date` on the nearest step.
    static func snap(_ date: Date) -> Date {
        let unit = Double(step) * 60
        return Date(timeIntervalSinceReferenceDate: (date.timeIntervalSinceReferenceDate / unit).rounded() * unit)
    }

    /// A cycle end within one step of `length` minutes from lying down.
    static func detent(near length: Int) -> Int? {
        let fall = Int(SleepSuggestion.fallAsleepTime / 60), cycle = Int(SleepSuggestion.cycleLength / 60)
        return (1...8).map { fall + $0 * cycle }.first { abs($0 - length) <= step }
    }

    private static func gap(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }

    // MARK: Geometry

    static func wrap(_ minutes: Int) -> Int { (minutes % day + day) % day }

    private func minutesOfDay(_ date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    /// Clock face: midnight at the top, so an offset from now sits at its clock time.
    private var rotation: Int { minutesOfDay(top) }

    private func degrees(_ offset: Double) -> Double { (offset + Double(rotation)) / Double(Self.day) * 360 }

    private func point(_ offset: Double, radius: CGFloat, center: CGPoint) -> CGPoint {
        let angle = degrees(offset) * .pi / 180
        return CGPoint(x: center.x + radius * sin(angle), y: center.y - radius * cos(angle))
    }

    /// Clockwise from the top, snapped to `step`.
    private func offset(at location: CGPoint, center: CGPoint) -> Int {
        var angle = atan2(location.x - center.x, center.y - location.y)
        if angle < 0 { angle += 2 * .pi }
        let raw = angle / (2 * .pi) * Double(Self.day) - Double(rotation)
        return Self.wrap(Int((raw / Double(Self.step)).rounded()) * Self.step)
    }

    private static func hourText(_ hour: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now) ?? .now
        return date.formatted(.dateTime.hour())
    }
}
