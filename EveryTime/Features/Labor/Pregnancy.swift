import Foundation

/// Where the pregnancy is, from the due date: ACOG term categories and what to get ready.
struct Pregnancy: Equatable {
    let weeks: Int
    let days: Int
    let daysToDue: Int

    init?(settings: LaborSettings, now: Date, calendar: Calendar = .current) {
        guard let g = settings.gestation(at: now, calendar: calendar) else { return nil }
        weeks = g.weeks
        days = g.days
        daysToDue = g.daysToDue
    }

    /// ACOG Committee Opinion 579.
    enum Term: Equatable {
        case preterm, earlyTerm, fullTerm, lateTerm, postTerm

        var title: String {
            switch self {
            case .preterm: "Preterm"
            case .earlyTerm: "Early term"
            case .fullTerm: "Full term"
            case .lateTerm: "Late term"
            case .postTerm: "Post-term"
            }
        }
    }

    var term: Term {
        switch weeks {
        case ..<37: .preterm
        case 37...38: .earlyTerm
        case 39...40: .fullTerm
        case 41: .lateTerm
        default: .postTerm
        }
    }

    var weeksText: String { Self.weeksText(weeks: weeks, days: days) }

    static func weeksText(weeks: Int, days: Int) -> String {
        days == 0 ? "\(weeks) weeks" : "\(weeks) weeks \(days) day\(days == 1 ? "" : "s")"
    }

    var dueText: String {
        switch daysToDue {
        case 0: "Due today"
        case 1: "Due tomorrow"
        case 2...: "Due in \(daysToDue) days"
        case -1: "1 day past the due date"
        default: "\(-daysToDue) days past the due date"
        }
    }

    /// One line of what matters this week.
    var tip: String {
        switch weeks {
        case ..<28: "Contractions, bleeding or waters this early are worth a call to your care team."
        case 28..<34: "Learn the signs of preterm labor. Start packing the hospital bag."
        case 34..<36: "Pack the bag, install the car seat, try the route to the hospital."
        case 36: "GBS test is usually now (36–37 weeks). Finish the checklist below."
        case 37...38: "Baby could come any day now. Keep the phone charged and the tank full."
        case 39...40: "Your due window. Know your plan: when to call, how to get there."
        case 41: "Past the due date is common. Your care team may talk about checks or induction."
        default: "Follow your care team's plan closely; ask about monitoring and induction."
        }
    }
}

/// Things to have ready before labor; ticks are kept per labor.
enum PrepItem: String, CaseIterable, Codable {
    case bag, carSeat, route, phone, ride, gbs, siblings, plan

    var title: String {
        switch self {
        case .bag: "Hospital bag packed (IDs, insurance, phone charger)"
        case .carSeat: "Car seat installed"
        case .route: "Route and night entrance checked"
        case .phone: "Labor and delivery number saved"
        case .ride: "Ride and a backup driver arranged"
        case .gbs: "GBS test done (36–37 weeks)"
        case .siblings: "Someone to look after the other kids"
        case .plan: "Labor plan set up in this app"
        }
    }

    static func items(firstBaby: Bool) -> [PrepItem] { allCases.filter { firstBaby ? $0 != .siblings : true } }
}
