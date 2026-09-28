import SwiftUI

/// One night on a 24-hour dial, midnight at the top: drag the bed or wake handle, or the arc to move both.
struct NightDial: View {
    /// Minutes after midnight.
    struct Hours: Equatable {
        var bed: Int
        var wake: Int

        var length: Int { NightDial.wrap(wake - bed) }

        /// Moves one end, stopping at the shortest or longest night instead of jumping past it.
        func moving(bed newBed: Int? = nil, wake newWake: Int? = nil) -> Hours {
            let proposed = Hours(bed: NightDial.wrap(newBed ?? bed), wake: NightDial.wrap(newWake ?? wake))
            guard !NightDial.lengths.contains(proposed.length) else { return proposed }
            let limit = NightDial.arc(proposed.length, NightDial.lengths.lowerBound)
                < NightDial.arc(proposed.length, NightDial.lengths.upperBound)
                ? NightDial.lengths.lowerBound : NightDial.lengths.upperBound
            return newBed != nil ? Hours(bed: NightDial.wrap(wake - limit), wake: wake)
                : Hours(bed: bed, wake: NightDial.wrap(bed + limit))
        }

        func shifted(by minutes: Int) -> Hours {
            Hours(bed: NightDial.wrap(bed + minutes), wake: NightDial.wrap(wake + minutes))
        }
    }

    @Binding var hours: Hours

    static let lengths = 3 * 60 ... 14 * 60
    static let step = 5
    private static let day = 24 * 60

    private enum Grab: Equatable { case bed, wake, night(at: Int) }
    @State private var grab: Grab?

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let track = side * 0.16
            let radius = (side - track) / 2
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let point = { (minutes: Int, r: CGFloat) in Self.point(minutes, radius: r, center: center) }
            ZStack {
                Circle()
                    .stroke(Theme.cardFill, lineWidth: track)
                    .frame(width: radius * 2, height: radius * 2)
                    .position(center)
                face(radius: radius - track / 2 - 6, point: point)
                Circle()
                    .trim(from: 0, to: Double(hours.length) / Double(Self.day))
                    .stroke(Color.indigo.gradient, style: StrokeStyle(lineWidth: track - 8, lineCap: .round))
                    .rotationEffect(.degrees(Self.degrees(hours.bed) - 90))
                    .frame(width: radius * 2, height: radius * 2)
                    .position(center)
                ForEach(cycleEnds, id: \.self) { minutes in
                    Circle().fill(.white.opacity(0.75)).frame(width: 5, height: 5).position(point(minutes, radius))
                }
                handle("bed.double.fill", size: track - 12, isGrabbed: grab == .bed).position(point(hours.bed, radius))
                handle("alarm.fill", size: track - 12, isGrabbed: grab == .wake).position(point(hours.wake, radius))
                readout(side: side).position(center)
            }
            .contentShape(Rectangle())
            .gesture(drag(center: center, radius: radius, track: track))
        }
        .aspectRatio(1, contentMode: .fit)
        .sensoryFeedback(.selection, trigger: hours)
        .sensoryFeedback(trigger: grab) { old, new in old == nil && new != nil ? .impact(weight: .light) : nil }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Night")
        .accessibilityValue("\(hours.bed.timeOfDayText) to \(hours.wake.timeOfDayText), \(NapAdvice.hours(Double(hours.length) / 60))")
    }

    /// Where each full cycle ends, after ~15 minutes to fall asleep.
    private var cycleEnds: [Int] {
        let first = Int(SleepSuggestion.fallAsleepTime / 60), cycle = Int(SleepSuggestion.cycleLength / 60)
        return stride(from: first + cycle, to: hours.length - 10, by: cycle).map { Self.wrap(hours.bed + $0) }
    }

    private func face(radius: CGFloat, point: @escaping (Int, CGFloat) -> CGPoint) -> some View {
        ZStack {
            ForEach(0..<24, id: \.self) { hour in
                let isMajor = hour % 6 == 0
                Capsule()
                    .fill(Color.primary.opacity(isMajor ? 0.35 : 0.15))
                    .frame(width: isMajor ? 2 : 1.5, height: isMajor ? 8 : 5)
                    .rotationEffect(.degrees(Self.degrees(hour * 60)))
                    .position(point(hour * 60, radius))
                if isMajor {
                    Text(Self.hourText(hour))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .position(point(hour * 60, radius - 18))
                }
            }
        }
    }

    private func handle(_ symbol: String, size: CGFloat, isGrabbed: Bool) -> some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(.indigo)
            .frame(width: size, height: size)
            .background(.white, in: Circle())
            .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
            .scaleEffect(isGrabbed ? 1.15 : 1)
            .animation(.snappy(duration: 0.15), value: isGrabbed)
    }

    private func readout(side: CGFloat) -> some View {
        let fit = SleepSuggestion.fit(minutesInBed: hours.length)
        return VStack(spacing: 4) {
            Text(NapAdvice.hours(Double(hours.length) / 60))
                .font(.clock(side * 0.12, weight: .regular))
                .contentTransition(.numericText())
            Text("\(fit.cycles) \(fit.cycles == 1 ? "cycle" : "cycles")")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            CycleFitLabel(isBetweenCycles: fit.isBetweenCycles)
                .font(.caption)
        }
    }

    // MARK: Dragging

    private func drag(center: CGPoint, radius: CGFloat, track: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let minutes = Self.minutes(at: value.location, center: center)
                if grab == nil {
                    grab = pick(value.startLocation, center: center, radius: radius, track: track)
                }
                switch grab {
                case .bed: hours = hours.moving(bed: minutes)
                case .wake: hours = hours.moving(wake: minutes)
                case .night(let from):
                    let delta = Self.wrap(minutes - from + Self.day / 2) - Self.day / 2
                    hours = hours.shifted(by: delta)
                    grab = .night(at: minutes)
                case nil: break
                }
            }
            .onEnded { _ in grab = nil }
    }

    /// The handle nearest the touch, or the arc between them; nothing off the track.
    private func pick(_ location: CGPoint, center: CGPoint, radius: CGFloat, track: CGFloat) -> Grab? {
        let distance = hypot(location.x - center.x, location.y - center.y)
        guard abs(distance - radius) < track / 2 + 16 else { return nil }
        let toBed = Self.gap(location, Self.point(hours.bed, radius: radius, center: center))
        let toWake = Self.gap(location, Self.point(hours.wake, radius: radius, center: center))
        if min(toBed, toWake) < track * 0.8 { return toBed <= toWake ? .bed : .wake }
        let minutes = Self.minutes(at: location, center: center)
        return Self.wrap(minutes - hours.bed) <= hours.length ? .night(at: minutes) : nil
    }

    // MARK: Geometry

    static func wrap(_ minutes: Int) -> Int { (minutes % day + day) % day }

    /// Minutes between two clock times, whichever way round is shorter.
    static func arc(_ a: Int, _ b: Int) -> Int { min(wrap(a - b), wrap(b - a)) }

    private static func degrees(_ minutes: Int) -> Double { Double(minutes) / Double(day) * 360 }

    private static func point(_ minutes: Int, radius: CGFloat, center: CGPoint) -> CGPoint {
        let angle = Double(minutes) / Double(day) * 2 * .pi
        return CGPoint(x: center.x + radius * sin(angle), y: center.y - radius * cos(angle))
    }

    /// Clockwise from the top, snapped to `step`.
    private static func minutes(at location: CGPoint, center: CGPoint) -> Int {
        var angle = atan2(location.x - center.x, center.y - location.y)
        if angle < 0 { angle += 2 * .pi }
        let raw = angle / (2 * .pi) * Double(day)
        return wrap(Int((raw / Double(step)).rounded()) * step)
    }

    private static func gap(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }

    private static func hourText(_ hour: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now) ?? .now
        return date.formatted(.dateTime.hour())
    }
}

/// Green tick when the wake lands between cycles, orange when it cuts one short.
struct CycleFitLabel: View {
    let isBetweenCycles: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isBetweenCycles ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
            Text(isBetweenCycles ? "Wakes between cycles" : "Wakes mid-cycle")
        }
        .foregroundStyle(isBetweenCycles ? Theme.Tone.good : Theme.Tone.warn)
    }
}
