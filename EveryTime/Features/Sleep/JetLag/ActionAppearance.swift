import SwiftUI

enum TimelineColumn: CaseIterable {
    case light, caffeine, sleep, melatonin

    var title: String {
        switch self {
        case .light: "Light"
        case .caffeine: "Caffeine"
        case .sleep: "Sleep"
        case .melatonin: ""
        }
    }
}

extension ActionKind {
    var title: String {
        switch self {
        case .brightLight: "See bright light"
        case .someLight: "Some light is fine"
        case .avoidLight: "Avoid bright light"
        case .caffeineOK: "Caffeine OK"
        case .caffeineAvoid: "Avoid caffeine"
        case .sleep: "Sleep"
        case .sleepIfYouCan: "Sleep if you can"
        case .nap: "Nap if you can"
        case .melatonin: "Melatonin"
        case .flight: "Flight"
        }
    }

    var legendTitle: String {
        switch self {
        case .brightLight: "Bright"
        case .someLight: "Some light"
        case .avoidLight: "No light"
        case .caffeineOK: "Caffeine"
        case .caffeineAvoid: "No caffeine"
        case .sleep: "Sleep"
        case .sleepIfYouCan: "Sleep if you can"
        case .nap: "Nap"
        case .melatonin: "Melatonin"
        case .flight: "Flight"
        }
    }

    var tip: String {
        switch self {
        case .brightLight: "Go outside or use a light box."
        case .someLight: "Normal daylight is fine — no need to seek it out."
        case .avoidLight: "Stay in dim light; wear sunglasses outside."
        case .caffeineOK: "Coffee or tea is fine if you want it."
        case .caffeineAvoid: "Skip coffee, tea, cola and energy drinks."
        case .sleep: "Dark, cool, quiet room — keep this window even if you're not tired."
        case .sleepIfYouCan: "Try to sleep on the plane — eye mask and earplugs help."
        case .nap: "Keep it to 20–30 minutes to avoid grogginess."
        case .melatonin: "0.5 mg. Not medical advice — check with a doctor."
        case .flight: "In the air."
        }
    }

    var symbol: String {
        switch self {
        case .brightLight: "sun.max.fill"
        case .someLight: "sun.min.fill"
        case .avoidLight: "sun.max"
        case .caffeineOK: "cup.and.saucer.fill"
        case .caffeineAvoid: "cup.and.saucer"
        case .sleep: "moon.fill"
        case .sleepIfYouCan: "moon.zzz"
        case .nap: "zzz"
        case .melatonin: "pills.fill"
        case .flight: "airplane"
        }
    }

    var isAvoid: Bool { self == .avoidLight || self == .caffeineAvoid }

    var color: Color {
        switch self {
        case .brightLight: .yellow
        case .someLight, .avoidLight: Color(red: 1, green: 0.72, blue: 0.4)
        case .caffeineOK, .caffeineAvoid: .brown
        case .sleep: Color(red: 0.12, green: 0.17, blue: 0.4)
        case .sleepIfYouCan, .nap: Color(red: 0.42, green: 0.5, blue: 0.8)
        case .melatonin: .purple
        case .flight: .gray
        }
    }

    var iconColor: Color {
        switch self {
        case .brightLight, .someLight: .black.opacity(0.7)
        case .avoidLight, .caffeineAvoid: color
        default: .white
        }
    }

    var column: TimelineColumn? {
        switch self {
        case .brightLight, .someLight, .avoidLight: .light
        case .caffeineOK, .caffeineAvoid: .caffeine
        case .sleep, .sleepIfYouCan, .nap: .sleep
        case .melatonin: .melatonin
        case .flight: nil
        }
    }
}

/// Kind symbol, slashed for "avoid" kinds.
struct ActionIcon: View {
    let kind: ActionKind

    var body: some View {
        Image(systemName: kind.symbol)
            .overlay {
                if kind.isAvoid {
                    Image(systemName: "line.diagonal")
                        .rotationEffect(.degrees(90))
                        .fontWeight(.heavy)
                }
            }
    }
}

/// Capsule filled for do-this kinds, outlined for avoid kinds.
struct ActionCapsule: View {
    let kind: ActionKind

    var body: some View {
        Capsule(style: .continuous)
            .fill(kind.isAvoid ? Color.clear : kind.color)
            .overlay {
                if kind.isAvoid { Capsule(style: .continuous).strokeBorder(kind.color, lineWidth: 2) }
            }
    }
}

struct ActionDetail: View {
    let action: PlanAction
    let timeZone: TimeZone

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text(action.kind.title).font(.cardTitle)
            } icon: {
                ActionIcon(kind: action.kind).foregroundStyle(action.kind.color)
            }
            Text(action.timeRange(in: timeZone)).font(.clock(22, weight: .regular))
            Text(action.kind.tip).font(.callout).foregroundStyle(.secondary)
        }
        .padding()
        .frame(idealWidth: 280, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .presentationCompactAdaptation(.popover)
    }
}

struct InfoButton: View {
    let label: String
    let text: String
    @State private var isShown = false

    var body: some View {
        Button { isShown = true } label: { Image(systemName: "info.circle") }
            .buttonStyle(.borderless)
            .accessibilityLabel(label)
            .popover(isPresented: $isShown) {
                Text(text)
                    .font(.callout)
                    .padding()
                    .frame(idealWidth: 280)
                    .fixedSize(horizontal: false, vertical: true)
                    .presentationCompactAdaptation(.popover)
            }
    }
}
