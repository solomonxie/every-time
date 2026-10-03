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

/// A 24-hour ring like a clock, midnight at the top, with a pin at now: drag the night (and any naps) to see cycles and how waking would feel.
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

    private enum Part: Equatable { case night, nap(Int) }
    private enum Grab: Equatable {
        case start(Part), end(Part), whole(Part, at: Int), pin

        var part: Part? {
            switch self {
            case .start(let p), .end(let p), .whole(let p, _): p
            case .pin: nil
            }
        }
    }

    @Stored("sleep.ring.night") private var storedNight: DateInterval? = nil
    @Stored("sleep.ring.naps") private var storedNaps: [DateInterval] = []
    @State private var grab: Grab?
    /// Whose length and cycles show under the ring: the last one touched.
    @State private var focus = Part.night
    /// Where the pin was dragged to plan from; nil = now.
    @State private var cursor: Int?
    /// One bright blink when a hold takes hold.
    @State private var flash = false

    static let step = 10
    private static let day = 24 * 60
    private static let nightLengths = 20 ... 14 * 60
    private static let napLengths = 10 ... 90

    /// The ring's top: now, floored to `step`.
    private var top: Date {
        let minutes = Int(now.timeIntervalSinceReferenceDate / 60)
        return Date(timeIntervalSinceReferenceDate: Double(minutes - minutes % Self.step) * 60)
    }

    var body: some View {
        let night = plan.map(span) ?? night ?? usualNight
        VStack(spacing: 16) {
            let shown = plan == nil ? focusedNap : nil
            header(night: shown ?? night, isNap: shown != nil)
            ring(night: night)
            readout(night: shown ?? night, isNap: shown != nil, side: 260)
            if let plan { waiting(plan) } else {
                summary(night: night)
                actions(night: night)
            }
        }
        .sensoryFeedback(.selection, trigger: night)
        .sensoryFeedback(.selection, trigger: naps)
        .sensoryFeedback(trigger: grab == nil) { _, released in released ? nil : .impact(weight: .medium) }
        .onChange(of: grab == nil) { _, released in
            guard !released else { return }
            flash = true
            withAnimation(.easeOut(duration: 0.35).delay(0.08)) { flash = false }
        }
        .onChange(of: top) { (old: Date, new: Date) in
            let d = Int(new.timeIntervalSince(old) / 60)
            // Once the night starts a new day begins: the day's naps are done.
            if let bed = storedNight?.start, bed <= new { storedNaps.removeAll { $0.start < bed } }
            if focusedNap == nil { focus = .night }
            cursor = cursor.flatMap { $0 - d > 0 ? $0 - d : nil }
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

    /// Kept as clock times so they survive relaunches; past ones drop off.
    private var night: Span? {
        get { storedNight.flatMap { $0.end > top ? span($0) : nil } }
        nonmutating set { storedNight = newValue.map(interval) }
    }

    private var naps: [Span] {
        get { storedNaps.filter { $0.end > top }.map(span) }
        nonmutating set { storedNaps = newValue.map(interval) }
    }

    private func span(_ interval: DateInterval) -> Span {
        let offset = { (d: Date) in Int((d.timeIntervalSince(top) / 60).rounded()) }
        return Span(start: max(0, offset(interval.start)), end: min(Self.day, offset(interval.end)))
    }

    private func interval(_ span: Span) -> DateInterval { DateInterval(start: date(span.start), end: date(span.end)) }

    private func date(_ offset: Int) -> Date { top.addingTimeInterval(Double(offset) * 60) }

    private func minutesOfDay(_ date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    private func fit(_ span: Span, isNap: Bool = false) -> WakeFit {
        isNap ? WakeFit.nap(length: Double(span.length) * 60) : WakeFit.of(length: Double(span.length) * 60)
    }

    private var focusedNap: Span? {
        if case .nap(let i) = focus, naps.indices.contains(i) { return naps[i] }
        return nil
    }

    // MARK: Ring

    private func ring(night: Span) -> some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let track = side * 0.17
            // Room outside the track for the pin's knob.
            let radius = (side - track) / 2 - 18
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let point = { (offset: Double, r: CGFloat) in self.point(offset, radius: r, center: center) }
            ZStack {
                Circle().stroke(Color.primary.opacity(0.08), lineWidth: track)
                    .frame(width: radius * 2, height: radius * 2).position(center)
                Circle().fill(Theme.cardFill).frame(width: (radius - track / 2 - 6) * 2, height: (radius - track / 2 - 6) * 2).position(center)
                face(radius: radius - track / 2 - 14, point: point)
                cycles(night, radius: radius, track: track, center: center)
                arc(night, color: fit(night).color, width: track - 6, radius: radius, center: center, lit: lit(.night))
                ForEach(Array((plan == nil ? naps : []).enumerated()), id: \.offset) { i, nap in
                    arc(nap, color: fit(nap, isNap: true).color.opacity(0.7), width: track * 0.55, radius: radius, center: center, lit: lit(.nap(i)))
                    handle("cup.and.saucer.fill", size: track * 0.62, isGrabbed: held(.start(.nap(i)), .nap(i)))
                        .position(point(Double(nap.start), radius))
                    handle("alarm", size: track * 0.62, isGrabbed: held(.end(.nap(i)), .nap(i)))
                        .position(point(Double(nap.end), radius))
                }
                handle("bed.double.fill", size: track - 10, isGrabbed: held(.start(.night), .night))
                    .position(point(Double(night.start), radius))
                handle("alarm.fill", size: track - 10, isGrabbed: held(.end(.night), .night))
                    .position(point(Double(night.end), radius))
                Capsule().fill(.primary.opacity(cursor == nil ? 1 : 0.35)).frame(width: 3, height: track + 6)
                    .rotationEffect(.degrees(degrees(0))).position(point(0, radius))
                if plan == nil { pin(radius: radius, track: track, point: point) }
                if let plan { countdown(to: plan.start, side: side).position(center) } else { pinTime(side: side).position(center) }
            }
            .contentShape(Rectangle())
            .gesture(drag(night: night, center: center, radius: radius, track: track), including: plan == nil ? .all : .subviews)
            .simultaneousGesture(SpatialTapGesture().onEnded { tap in
                if plan == nil, let part = pick(tap.location, night: night, center: center, radius: radius, track: track)?.part { focus = part }
            })
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sleep ring")
        .accessibilityValue("\(SleepNow.clock(date(night.start))) to \(SleepNow.clock(date(night.end))), \(fit(night).text)")
    }

    private func lit(_ part: Part) -> Bool { flash && grab?.part == part }

    /// That handle, or its whole range, is held.
    private func held(_ handle: Grab, _ part: Part) -> Bool {
        if grab == handle { return true }
        if case .whole(let p, _) = grab { return p == part }
        return false
    }

    private func arc(_ span: Span, color: Color, width: CGFloat, radius: CGFloat, center: CGPoint, lit: Bool) -> some View {
        Circle()
            .trim(from: Double(span.start) / Double(Self.day), to: Double(span.end) / Double(Self.day))
            .stroke(color.gradient, style: StrokeStyle(lineWidth: width, lineCap: .round))
            .overlay {
                Circle()
                    .trim(from: Double(span.start) / Double(Self.day), to: Double(span.end) / Double(Self.day))
                    .stroke(.white, style: StrokeStyle(lineWidth: width, lineCap: .round))
                    .opacity(lit ? 0.85 : 0)
            }
            .shadow(color: lit ? .white.opacity(0.8) : .clear, radius: lit ? 12 : 0)
            .rotationEffect(.degrees(-90 + degrees(0)))
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
                    .stroke(Color.indigo.opacity(i < 3 ? 0.45 : 0.2), lineWidth: track * 0.2)
                    .rotationEffect(.degrees(-90 + degrees(0)))
                    .frame(width: (radius + track * 0.38) * 2, height: (radius + track * 0.38) * 2)
                    .position(center)
                if s + cycle < Double(Self.day) {
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

    /// Hold and drag along the rim to plan from a later time.
    private func pin(radius: CGFloat, track: CGFloat, point: (Double, CGFloat) -> CGPoint) -> some View {
        let at = Double(cursor ?? 0)
        let isHeld = grab == .pin, isLit = flash && grab == .pin
        return ZStack {
            Capsule().fill(Color.orange.gradient).frame(width: 4, height: track + 10)
                .shadow(color: .black.opacity(0.4), radius: 2)
                .rotationEffect(.degrees(degrees(at))).position(point(at, radius))
            Circle().fill(isLit ? AnyShapeStyle(.white) : AnyShapeStyle(Color.orange.gradient))
                .overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: 2))
                .frame(width: 16, height: 16)
                .shadow(color: isLit ? .orange : .black.opacity(0.3), radius: isLit ? 10 : 2)
                .scaleEffect(isLit ? 1.6 : isHeld ? 1.3 : 1)
                .position(point(at, radius + track / 2 + 9))
        }
        .animation(.snappy(duration: 0.2), value: isHeld)
    }

    /// The pin's time in the middle of the face: now, or how far ahead it's been dragged.
    private func pinTime(side: CGFloat) -> some View {
        let at = cursor ?? 0
        return VStack(spacing: 2) {
            Text(SleepNow.clock(cursor == nil ? now : date(at)))
                .font(.clock(side * 0.09, weight: .semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(cursor == nil ? Color.primary : Color.orange)
            Text(cursor == nil ? "Now" : "in \(ActivityLog.duration(date(at).timeIntervalSince(now)))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .animation(.snappy(duration: 0.15), value: at)
    }

    private func handle(_ symbol: String, size: CGFloat, isGrabbed: Bool) -> some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(.black.opacity(0.65))
            .frame(width: size, height: size)
            .scaleEffect(isGrabbed ? 1.15 : 1)
            .animation(.snappy(duration: 0.15), value: isGrabbed)
    }

    private func readout(night: Span, isNap: Bool, side: CGFloat) -> some View {
        let fit = fit(night, isNap: isNap)
        let cycles = max(0, Double(night.length) * 60 - SleepSuggestion.fallAsleepTime) / SleepSuggestion.cycleLength
        return VStack(spacing: 4) {
            Label(isNap ? "Nap" : "Sleep", systemImage: isNap ? "cup.and.saucer.fill" : "bed.double.fill")
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(NapAdvice.hours(Double(night.length) / 60))
                .font(.clock(side * 0.11, weight: .regular))
                .contentTransition(.numericText())
            Text(isNap ? "~\(max(0, night.length - Int(SleepSuggestion.fallAsleepTime / 60))) min asleep"
                 : "\(cycles.formatted(.number.precision(.fractionLength(1)))) cycles")
                .font(.subheadline).foregroundStyle(.secondary)
            Label(fit.text(isNap: isNap), systemImage: fit == .good ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.caption).foregroundStyle(fit == .poor ? Theme.Tone.bad : fit == .good ? Theme.Tone.good : .orange)
        }
    }

    private func header(night: Span, isNap: Bool) -> some View {
        HStack {
            end(isNap ? "cup.and.saucer.fill" : "bed.double.fill", isNap ? "Nap" : "Bedtime", night.start)
            end(isNap ? "alarm" : "alarm.fill", "Wake up", night.end)
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
            ForEach(naps.sorted { $0.start < $1.start }, id: \.start) { row("cup.and.saucer.fill", "Nap", $0, isNap: true) }
            if naps.contains(where: { $0.end > night.start && $0.start < night.end }) {
                Text("A nap overlaps the night").font(.footnote).foregroundStyle(Theme.Tone.warn)
            } else if let nap = naps.filter({ $0.end <= night.start }).max(by: { $0.end < $1.end }) {
                let gap = night.start - nap.end
                Text("Nap ends \(ActivityLog.duration(Double(gap) * 60)) before bed\(gap < 6 * 60 ? " — may delay falling asleep" : "")")
                    .font(.footnote).foregroundStyle(gap < 6 * 60 ? Theme.Tone.warn : .secondary)
            }
            Text("Shaded: each cycle's deep sleep. Hold a handle to resize, or the arc to move. \(Int(SleepSuggestion.fallAsleepTime / 60)) min to drift off.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ symbol: String, _ title: String, _ span: Span, isNap: Bool = false) -> some View {
        HStack {
            Label(title, systemImage: symbol).font(.subheadline.weight(.semibold))
            Spacer()
            Text("\(SleepNow.clock(date(span.start))) → \(SleepNow.clock(date(span.end)))").monospacedDigit()
            Circle().fill(fit(span, isNap: isNap).color).frame(width: 10, height: 10)
        }
    }

    private func actions(night: Span) -> some View {
        VStack(spacing: 10) {
        if let cursor {
            HStack(spacing: Theme.spacing) {
                Button("Now", systemImage: "arrow.uturn.backward") { withAnimation(.snappy) { self.cursor = nil } }
                    .buttonStyle(.soft)
                Button("Sleep here", systemImage: "bed.double.fill") {
                    withAnimation(.snappy) {
                        self.night = Span(start: cursor, end: min(Self.day, cursor + night.length))
                        focus = .night
                    }
                }
                .buttonStyle(.soft)
            }
        }
        HStack(spacing: Theme.spacing) {
            if case .nap(let i) = focus, focusedNap != nil {
                Button {
                    withAnimation(.snappy) { naps.remove(at: i); focus = .night }
                } label: { Label("Remove nap", systemImage: "minus") }
                .buttonStyle(.soft)
            } else {
                Button {
                    withAnimation(.snappy) {
                        naps.append(freeNap(night: night))
                        focus = .nap(naps.count - 1)
                    }
                } label: { Label(cursor == nil ? "Add nap" : "Nap here", systemImage: "plus") }
                .buttonStyle(.soft)
            }
            Button { commit((naps + [night]).min { $0.start < $1.start } ?? night) } label: {
                Label("Set alarm", systemImage: "alarm.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.primary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
    }

    /// The first thing ahead gets the alarm: a nap before the night, else the night.
    /// A nap leaves the ring once it's the one being slept.
    private func commit(_ span: Span) {
        if let i = naps.firstIndex(of: span) { naps.remove(at: i); focus = .night }
        if span.start == 0 { NapSession.start(minutes: span.length) } else { NapSession.plan(bed: date(span.start), wake: date(span.end)) }
    }

    /// The earliest gap from now that fits a nap clear of the night and other naps.
    private func freeNap(night: Span) -> Span {
        let length = Self.napLength
        let taken = (naps + [night]).sorted { $0.start < $1.start }
        var start = cursor ?? 0
        for span in taken where span.start < start + length + Self.step {
            start = max(start, span.end + Self.step)
        }
        start = min(start, Self.day - length)
        return Span(start: start, end: start + length)
    }

    /// At least 25 min with 10+ min actually asleep, waking before deep sleep.
    static var napLength: Int {
        stride(from: 25, through: napLengths.upperBound, by: 5)
            .first { Double($0) * 60 - SleepSuggestion.fallAsleepTime >= 10 * 60 && WakeFit.nap(length: Double($0) * 60) == .good } ?? 25
    }

    // MARK: Dragging

    /// Hold to grab, then drag: a plain tap only picks which range the stats show.
    private func drag(night: Span, center: CGPoint, radius: CGFloat, track: CGFloat) -> some Gesture {
        LongPressGesture(minimumDuration: 0.15, maximumDistance: 12)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { sequence in
                guard case .second(true, let value?) = sequence else { return }
                let offset = self.offset(at: value.location, center: center)
                if grab == nil {
                    grab = pick(value.startLocation, night: night, center: center, radius: radius, track: track)
                    if let part = grab?.part { focus = part }
                }
                guard let grab else { return }
                switch grab {
                case .start(let part): update(part) { Self.resize($0, start: offset > $0.end ? 0 : offset, lengths: lengths(part)) }
                case .end(let part): update(part) { Self.resize($0, end: offset < $0.start ? Self.day : offset, lengths: lengths(part)) }
                case .pin: cursor = offset == 0 || offset >= Self.day - Self.step ? nil : offset
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
        case .nap(let i): if naps.indices.contains(i) { naps[i] = change(naps[i]) }
        }
    }

    /// Nearest handle, else the arc under the touch; the nap wins ties since it's smaller.
    private func pick(_ location: CGPoint, night: Span, center: CGPoint, radius: CGFloat, track: CGFloat) -> Grab? {
        let distance = hypot(location.x - center.x, location.y - center.y)
        guard abs(distance - radius) < track / 2 + 24 else { return nil }
        let gap = { (offset: Int) in Self.gap(location, self.point(Double(offset), radius: radius, center: center)) }
        let pinKnob = self.point(Double(cursor ?? 0), radius: radius + track / 2 + 9, center: center)
        if Self.gap(location, pinKnob) < 24 { return .pin }
        var handles: [(Grab, CGFloat)] = [(.start(.night), gap(night.start)), (.end(.night), gap(night.end))]
        for (i, nap) in naps.enumerated() { handles += [(.start(.nap(i)), gap(nap.start)), (.end(.nap(i)), gap(nap.end))] }
        if let nearest = handles.min(by: { $0.1 < $1.1 }), nearest.1 < track * 0.8 { return nearest.0 }
        let offset = self.offset(at: location, center: center)
        if let i = naps.firstIndex(where: { ($0.start...$0.end).contains(offset) }) { return .whole(.nap(i), at: offset) }
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

    static func wrap(_ minutes: Int) -> Int { (minutes % day + day) % day }

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

    private static func gap(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }

    private static func hourText(_ hour: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now) ?? .now
        return date.formatted(.dateTime.hour())
    }
}
