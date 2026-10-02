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

/// A 24-hour ring with now at the top: drag the night (and an optional nap) to see cycles and how waking would feel.
struct SleepRing: View {
    let now: Date
    var profile = JetLagProfile()
    /// Already chosen: the ring just counts down to it.
    var plan: ActiveNap? = nil

    struct Span: Equatable {
        /// Minutes from the top of the ring.
        var start: Int
        var end: Int
        var length: Int { end - start }
    }

    private enum Part: Equatable { case night, nap }
    private enum Grab: Equatable { case start(Part), end(Part), whole(Part, at: Int) }

    @State private var night: Span?
    @State private var nap: Span?
    @State private var grab: Grab?

    static let step = 10
    private static let day = 24 * 60
    private static let nightLengths = 20 ... 14 * 60
    private static let napLengths = 10 ... 3 * 60

    /// The ring's top: now, floored to `step`.
    private var top: Date {
        let minutes = Int(now.timeIntervalSinceReferenceDate / 60)
        return Date(timeIntervalSinceReferenceDate: Double(minutes - minutes % Self.step) * 60)
    }

    var body: some View {
        let night = plan.map(span) ?? night ?? usualNight
        VStack(spacing: 16) {
            header(night: night)
            ring(night: night)
            readout(night: night, side: 260)
            if let plan { waiting(plan) } else {
                summary(night: night)
                actions(night: night)
            }
        }
        .sensoryFeedback(.selection, trigger: night)
        .sensoryFeedback(.selection, trigger: nap)
        .onChange(of: top) { (old: Date, new: Date) in
            let d = Int(new.timeIntervalSince(old) / 60)
            self.night = self.night.flatMap { Self.elapse($0, by: d) }
            nap = nap.flatMap { Self.elapse($0, by: d) }
        }
    }

    /// Next usual bed → wake; already in the usual night, from now.
    private var usualNight: Span {
        let nowMinutes = minutesOfDay(top)
        let bed = Self.wrap(profile.usualBedtime - nowMinutes)
        let wake = Self.wrap(profile.usualWake - nowMinutes)
        let span = bed < wake ? Span(start: bed, end: wake) : Span(start: 0, end: max(wake, Self.nightLengths.lowerBound))
        return span.length >= 60 ? span : Span(start: bed, end: min(Self.day, bed + 8 * 60))
    }

    private func span(_ plan: ActiveNap) -> Span {
        let offset = { (d: Date) in Int(d.timeIntervalSince(top) / 60) }
        return Span(start: max(0, offset(plan.start)), end: min(Self.day, offset(plan.alarm)))
    }

    private func date(_ offset: Int) -> Date { top.addingTimeInterval(Double(offset) * 60) }

    private func minutesOfDay(_ date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    private func fit(_ span: Span) -> WakeFit { WakeFit.of(length: Double(span.length) * 60) }

    // MARK: Ring

    private func ring(night: Span) -> some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let track = side * 0.17
            let radius = (side - track) / 2
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let point = { (offset: Double, r: CGFloat) in Self.point(offset, radius: r, center: center) }
            ZStack {
                Circle().stroke(Color.primary.opacity(0.08), lineWidth: track)
                    .frame(width: radius * 2, height: radius * 2).position(center)
                Circle().fill(Theme.cardFill).frame(width: (radius - track / 2 - 6) * 2, height: (radius - track / 2 - 6) * 2).position(center)
                face(radius: radius - track / 2 - 14, point: point)
                cycles(night, radius: radius, track: track, center: center)
                arc(night, color: fit(night).color, width: track - 6, radius: radius, center: center)
                if let nap {
                    arc(nap, color: fit(nap).color.opacity(0.7), width: track * 0.55, radius: radius, center: center)
                    handle("cup.and.saucer.fill", size: track * 0.62, isGrabbed: grab == .start(.nap))
                        .position(point(Double(nap.start), radius))
                    handle("alarm", size: track * 0.62, isGrabbed: grab == .end(.nap))
                        .position(point(Double(nap.end), radius))
                }
                handle("bed.double.fill", size: track - 10, isGrabbed: grab == .start(.night))
                    .position(point(Double(night.start), radius))
                handle("alarm.fill", size: track - 10, isGrabbed: grab == .end(.night))
                    .position(point(Double(night.end), radius))
                Capsule().fill(.primary).frame(width: 3, height: track + 6).position(point(0, radius))
                if let plan { countdown(to: plan.start, side: side).position(center) }
            }
            .contentShape(Rectangle())
            .gesture(drag(night: night, center: center, radius: radius, track: track), including: plan == nil ? .all : .subviews)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sleep ring")
        .accessibilityValue("\(SleepNow.clock(date(night.start))) to \(SleepNow.clock(date(night.end))), \(fit(night).text)")
    }

    private func arc(_ span: Span, color: Color, width: CGFloat, radius: CGFloat, center: CGPoint) -> some View {
        Circle()
            .trim(from: Double(span.start) / Double(Self.day), to: Double(span.end) / Double(Self.day))
            .stroke(color.gradient, style: StrokeStyle(lineWidth: width, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .frame(width: radius * 2, height: radius * 2)
            .position(center)
    }

    /// From bedtime on: each cycle's deep-sleep stretch shaded, a tick where it ends. Shown across the next 12 h.
    private func cycles(_ night: Span, radius: CGFloat, track: CGFloat, center: CGPoint) -> some View {
        let fall = SleepSuggestion.fallAsleepTime / 60, cycle = SleepSuggestion.cycleLength / 60
        let starts = (0..<12).map { Double(night.start) + fall + Double($0) * cycle }.filter { $0 < Double(night.start) + 12 * 60 }
        return ZStack {
            ForEach(Array(starts.enumerated()), id: \.offset) { i, s in
                let from = min(Double(Self.day), s + cycle * WakeFit.deep.lowerBound)
                let to = min(Double(Self.day), s + cycle * WakeFit.deep.upperBound)
                Circle()
                    .trim(from: from / Double(Self.day), to: to / Double(Self.day))
                    .stroke(Color.indigo.opacity(i < 3 ? 0.35 : 0.15), lineWidth: track * 0.3)
                    .rotationEffect(.degrees(-90))
                    .frame(width: (radius + track * 0.5) * 2, height: (radius + track * 0.5) * 2)
                    .position(center)
                if s + cycle < Double(Self.day) {
                    Capsule().fill(.primary.opacity(0.6))
                        .frame(width: 2, height: track * 0.5)
                        .rotationEffect(.degrees((s + cycle) / Double(Self.day) * 360))
                        .position(Self.point(s + cycle, radius: radius + track * 0.5, center: center))
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
                    .rotationEffect(.degrees(offset / Double(Self.day) * 360))
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

    private func handle(_ symbol: String, size: CGFloat, isGrabbed: Bool) -> some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(.black.opacity(0.65))
            .frame(width: size, height: size)
            .scaleEffect(isGrabbed ? 1.15 : 1)
            .animation(.snappy(duration: 0.15), value: isGrabbed)
    }

    private func readout(night: Span, side: CGFloat) -> some View {
        let fit = fit(night)
        let cycles = max(0, Double(night.length) * 60 - SleepSuggestion.fallAsleepTime) / SleepSuggestion.cycleLength
        return VStack(spacing: 4) {
            Text(NapAdvice.hours(Double(night.length) / 60))
                .font(.clock(side * 0.11, weight: .regular))
                .contentTransition(.numericText())
            Text("\(cycles.formatted(.number.precision(.fractionLength(1)))) cycles")
                .font(.subheadline).foregroundStyle(.secondary)
            Label(fit.text, systemImage: fit == .good ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.caption).foregroundStyle(fit == .poor ? Theme.Tone.bad : fit == .good ? Theme.Tone.good : .orange)
        }
    }

    private func header(night: Span) -> some View {
        HStack {
            end("bed.double.fill", "Bedtime", night.start)
            end("alarm.fill", "Wake up", night.end)
        }
    }

    private func end(_ symbol: String, _ title: String, _ offset: Int) -> some View {
        let time = date(offset)
        return VStack(spacing: 2) {
            Label(title.uppercased(), systemImage: symbol).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(SleepNow.clock(time)).font(.clock(30, weight: .semibold)).contentTransition(.numericText())
            Text(offset == 0 ? "Now" : Calendar.current.isDateInToday(time) ? "Today" : "Tomorrow")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Waiting for bed

    private func countdown(to bed: Date, side: CGFloat) -> some View {
        let left = bed.timeIntervalSince(now)
        let lead = WindDown.lead
        return VStack(spacing: 2) {
            Image(systemName: left <= lead ? "moon.zzz.fill" : "moon.stars.fill")
                .font(.title2).foregroundStyle(.indigo)
                .symbolEffect(.pulse, isActive: left <= lead)
            Text(ActivityLog.duration(max(0, left)))
                .font(.clock(side * 0.1, weight: .semibold))
                .contentTransition(.numericText())
            Text(left <= lead ? "Wind down" : "until bed").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func waiting(_ plan: ActiveNap) -> some View {
        let windDown = plan.start.addingTimeInterval(-WindDown.lead)
        let tips = windDown > now
            ? ["Wind-down reminder at \(SleepNow.clock(windDown))", "Dim screens and lights from then", "Last coffee ~8 h before bed"]
            : ["Lights low, screens away", "Cool, dark room", "Ready early? Tap below — the alarm stays"]
        return VStack(alignment: .leading, spacing: 12) {
            ForEach(tips, id: \.self) { tip in
                Label(tip, systemImage: "checkmark.circle").font(.subheadline).foregroundStyle(.secondary)
            }
            HStack(spacing: Theme.spacing) {
                Button("Cancel") { NapSession.cancel() }.buttonStyle(.soft).frame(maxWidth: 120)
                Button { NapSession.inBedNow() } label: {
                    Label("I'm in bed now", systemImage: "moon.zzz.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Below the ring

    private func summary(night: Span) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            row("bed.double.fill", "Sleep", night)
            if let nap { row("cup.and.saucer.fill", "Nap", nap) }
            if let nap, nap.end > night.start, nap.start < night.end {
                Text("Nap overlaps the night").font(.footnote).foregroundStyle(Theme.Tone.warn)
            } else if let nap, nap.end <= night.start {
                let gap = night.start - nap.end
                Text("Nap ends \(ActivityLog.duration(Double(gap) * 60)) before bed\(gap < 6 * 60 ? " — may delay falling asleep" : "")")
                    .font(.footnote).foregroundStyle(gap < 6 * 60 ? Theme.Tone.warn : .secondary)
            }
            Text("Shaded: each cycle's deep sleep. Drag a handle to resize, the arc to move. \(Int(SleepSuggestion.fallAsleepTime / 60)) min to drift off.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ symbol: String, _ title: String, _ span: Span) -> some View {
        HStack {
            Label(title, systemImage: symbol).font(.subheadline.weight(.semibold))
            Spacer()
            Text("\(SleepNow.clock(date(span.start))) → \(SleepNow.clock(date(span.end)))").monospacedDigit()
            Circle().fill(fit(span).color).frame(width: 10, height: 10)
        }
    }

    private func actions(night: Span) -> some View {
        HStack(spacing: Theme.spacing) {
            Button {
                withAnimation(.snappy) { nap = nap == nil ? freeNap(night: night) : nil }
            } label: {
                Label(nap == nil ? "Add nap" : "Remove nap", systemImage: nap == nil ? "plus" : "minus")
            }
            .buttonStyle(.soft)
            .frame(maxWidth: 150)
            Button { commit(nap.map { $0.start < night.start ? $0 : night } ?? night) } label: {
                Label("Set alarm", systemImage: "alarm.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.primary)
        }
    }

    /// The first thing ahead gets the alarm: a nap before the night, else the night.
    private func commit(_ span: Span) {
        if span.start == 0 { NapSession.start(minutes: span.length) } else { NapSession.plan(bed: date(span.start), wake: date(span.end)) }
    }

    /// 20 min from now if that's clear of the night, else 20 min after it.
    private func freeNap(night: Span) -> Span {
        let start = night.start >= 20 + 60 ? 0 : min(Self.day - 20, night.end + Self.step)
        return Span(start: start, end: start + 20)
    }

    // MARK: Dragging

    private func drag(night: Span, center: CGPoint, radius: CGFloat, track: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let offset = Self.offset(at: value.location, center: center)
                if grab == nil { grab = pick(value.startLocation, night: night, center: center, radius: radius, track: track) }
                guard let grab else { return }
                switch grab {
                case .start(let part): update(part) { Self.resize($0, start: offset > $0.end ? 0 : offset, lengths: lengths(part)) }
                case .end(let part): update(part) { Self.resize($0, end: offset < $0.start ? Self.day : offset, lengths: lengths(part)) }
                case .whole(let part, let from):
                    update(part) { Self.shift($0, by: Self.wrap(offset - from + Self.day / 2) - Self.day / 2) }
                    self.grab = .whole(part, at: offset)
                }
            }
            .onEnded { _ in grab = nil }
    }

    private func lengths(_ part: Part) -> ClosedRange<Int> { part == .night ? Self.nightLengths : Self.napLengths }

    private func update(_ part: Part, _ change: (Span) -> Span) {
        switch part {
        case .night: night = change(night ?? usualNight)
        case .nap: if let nap { self.nap = change(nap) }
        }
    }

    /// Nearest handle, else the arc under the touch; the nap wins ties since it's smaller.
    private func pick(_ location: CGPoint, night: Span, center: CGPoint, radius: CGFloat, track: CGFloat) -> Grab? {
        let distance = hypot(location.x - center.x, location.y - center.y)
        guard abs(distance - radius) < track / 2 + 16 else { return nil }
        let gap = { (offset: Int) in Self.gap(location, Self.point(Double(offset), radius: radius, center: center)) }
        var handles: [(Grab, CGFloat)] = [(.start(.night), gap(night.start)), (.end(.night), gap(night.end))]
        if let nap { handles += [(.start(.nap), gap(nap.start)), (.end(.nap), gap(nap.end))] }
        if let nearest = handles.min(by: { $0.1 < $1.1 }), nearest.1 < track * 0.8 { return nearest.0 }
        let offset = Self.offset(at: location, center: center)
        if let nap, (nap.start...nap.end).contains(offset) { return .whole(.nap, at: offset) }
        return (night.start...night.end).contains(offset) ? .whole(.night, at: offset) : nil
    }

    // MARK: Geometry

    static func resize(_ span: Span, start: Int? = nil, end: Int? = nil, lengths: ClosedRange<Int>) -> Span {
        if let start {
            let s = min(max(0, start), span.end - lengths.lowerBound)
            return Span(start: max(s, span.end - lengths.upperBound), end: span.end)
        }
        let e = max(min(day, end ?? span.end), span.start + lengths.lowerBound)
        return Span(start: span.start, end: min(e, span.start + lengths.upperBound))
    }

    /// Moves both ends, kept between now and 24 h out.
    static func shift(_ span: Span, by delta: Int) -> Span {
        let d = min(max(delta, -span.start), day - span.end)
        return Span(start: span.start + d, end: span.end + d)
    }

    /// Keeps a span on the same clock times as the top moves on; gone once it's over.
    static func elapse(_ span: Span, by minutes: Int) -> Span? {
        let end = span.end - minutes
        return end > 0 ? Span(start: max(0, span.start - minutes), end: end) : nil
    }

    static func wrap(_ minutes: Int) -> Int { (minutes % day + day) % day }

    private static func point(_ offset: Double, radius: CGFloat, center: CGPoint) -> CGPoint {
        let angle = offset / Double(day) * 2 * .pi
        return CGPoint(x: center.x + radius * sin(angle), y: center.y - radius * cos(angle))
    }

    /// Clockwise from the top, snapped to `step`.
    private static func offset(at location: CGPoint, center: CGPoint) -> Int {
        var angle = atan2(location.x - center.x, center.y - location.y)
        if angle < 0 { angle += 2 * .pi }
        let raw = angle / (2 * .pi) * Double(day)
        return min(day, Int((raw / Double(step)).rounded()) * step)
    }

    private static func gap(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }

    private static func hourText(_ hour: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now) ?? .now
        return date.formatted(.dateTime.hour())
    }
}
