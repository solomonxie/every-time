import Foundation

enum JetLagKey {
    static let profile = "sleep.jetlag.profile"
    static let trips = "sleep.jetlag.trips"
}

extension Trip {
    /// Plan anchored before the pre-adjust days, so it stays stable as time passes.
    func plan(for profile: JetLagProfile, now: Date = .now) -> JetLagPlan {
        let start = departure.addingTimeInterval(-Double(preAdjustDays + 1) * 86_400)
        return JetLagPlanner.plan(profile: profile, trip: self, now: min(now, start))
    }

    /// Destination clock minus origin clock, in hours; positive = east.
    var zoneShiftHours: Double {
        Double(destination.timeZone.secondsFromGMT(for: arrival) - origin.timeZone.secondsFromGMT(for: departure)) / 3600
    }

    var zoneShiftLabel: String {
        let minutes = Int((zoneShiftHours * 60).rounded())
        let sign = minutes > 0 ? "+" : minutes < 0 ? "−" : ""
        let h = abs(minutes) / 60, m = abs(minutes) % 60
        return m == 0 ? "\(sign)\(h)h" : "\(sign)\(h)h \(m)m"
    }

    func city(in timeZone: TimeZone) -> WorldCity {
        timeZone.identifier == destination.timeZoneIdentifier ? destination : origin
    }

    /// "Starts in 3 days" · "Adjusting · day 2 of 6" · "Adapted".
    func status(of plan: JetLagPlan, now: Date) -> (text: String, isPast: Bool) {
        guard let first = plan.days.first, let last = plan.days.last else {
            return arrival > now ? (startsIn(departure, now: now), false) : ("Arrived", true)
        }
        if now < first.start { return (startsIn(first.start, now: now), false) }
        if now >= last.end { return ("Adapted", true) }
        let adjusting = plan.days.filter { !$0.isAdapted }
        guard let index = adjusting.lastIndex(where: { $0.start <= now }), now < adjusting[index].end else {
            return ("Adapted", false)
        }
        return ("Adjusting · day \(index + 1) of \(adjusting.count)", false)
    }

    private func startsIn(_ date: Date, now: Date) -> String {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
        switch days {
        case ...0: return "Starts today"
        case 1: return "Starts tomorrow"
        default: return "Starts in \(days) days"
        }
    }
}

extension JetLagPlan {
    var adjustingDays: Int { days.filter { !$0.isAdapted }.count }
    var actions: [PlanAction] { days.flatMap(\.actions) }
}

extension PlanDay {
    var end: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
    }
}

extension Date {
    func formatted(_ style: Date.FormatStyle, in timeZone: TimeZone) -> String {
        var style = style
        style.timeZone = timeZone
        return formatted(style)
    }

    func time(in timeZone: TimeZone) -> String {
        formatted(.dateTime.hour().minute(), in: timeZone)
    }
}

extension PlanAction {
    func timeRange(in timeZone: TimeZone) -> String {
        guard end > start else { return start.time(in: timeZone) }
        return (start..<end).formatted(Date.IntervalFormatStyle(date: .omitted, time: .shortened, timeZone: timeZone))
    }
}
