import AudioToolbox
import SwiftUI

/// Time's-up side effects. Fires once per countdown per app run; Replay bypasses that.
@MainActor
enum CountdownFinish {
    private static var fired = Set<UUID>()
    private static let alarmSound: SystemSoundID = 1005

    static func hasFired(_ id: UUID) -> Bool { fired.contains(id) }
    static func markFired(_ id: UUID) { fired.insert(id) }
    static func reset(_ id: UUID) { fired.remove(id) }

    static func play(_ countdown: Countdown) {
        if countdown.vibrate { repeatEvery(0.7, times: 4) { AudioServicesPlaySystemSound(kSystemSoundID_Vibrate) } }
        if countdown.sound { repeatEvery(1.4, times: 3) { AudioServicesPlaySystemSound(alarmSound) } }
    }

    private static func repeatEvery(_ interval: TimeInterval, times: Int, _ action: @escaping () -> Void) {
        Task {
            for i in 0..<times {
                if i > 0 { try? await Task.sleep(for: .seconds(interval)) }
                action()
            }
        }
    }
}

/// Full-screen fireworks or confetti with the countdown's name; auto-hides after `duration`, tap to dismiss.
struct CelebrationOverlay: View {
    let effect: Countdown.Effect
    let title: String
    var duration: TimeInterval = 6
    let onDone: () -> Void
    @State private var start = Date.now

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSince(start)
                Canvas { ctx, size in
                    switch effect {
                    case .fireworks: Fireworks.draw(in: &ctx, size: size, time: t, until: duration)
                    case .confetti: Confetti.draw(in: &ctx, size: size, time: t)
                    }
                }
            }
            VStack(spacing: 8) {
                Text("Time's up!")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.4)
                if !title.isEmpty {
                    Text(title)
                        .font(.system(.title2, design: .rounded, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .padding(Theme.padding)
            .shadow(radius: 12)
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture(perform: onDone)
        .task {
            try? await Task.sleep(for: .seconds(duration))
            onDone()
        }
        .transition(.opacity)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Time's up. \(title). Tap to dismiss.")
    }
}

/// Deterministic 0..<1 noise so particles need no stored state.
private func noise(_ a: Int, _ b: Int) -> Double {
    var x = UInt64(truncatingIfNeeded: a &* 73_856_093 ^ b &* 19_349_663) &+ 0x9E37_79B9_7F4A_7C15
    x = (x ^ (x >> 30)) &* 0xBF58_476D_1CE4_E5B9
    x = (x ^ (x >> 27)) &* 0x94D0_49BB_1331_11EB
    x ^= x >> 31
    return Double(x % 10_000) / 10_000
}

private let palette: [Color] = [.yellow, .orange, .pink, .red, .mint, .cyan, .purple, .white]

private enum Fireworks {
    static let interval = 0.45
    static let life = 1.8
    static let sparks = 36

    static func draw(in ctx: inout GraphicsContext, size: CGSize, time: TimeInterval, until end: TimeInterval) {
        let last = Int(min(time, end - life) / interval)
        guard last >= 0 else { return }
        for burst in max(0, last - Int(life / interval) - 1)...last {
            let age = time - Double(burst) * interval
            guard age >= 0, age < life else { continue }
            let center = CGPoint(x: size.width * (0.15 + 0.7 * noise(burst, 1)),
                                 y: size.height * (0.12 + 0.45 * noise(burst, 2)))
            let color = palette[Int(noise(burst, 3) * Double(palette.count))]
            let reach = min(size.width, size.height) * (0.22 + 0.14 * noise(burst, 4))
            let fade = 1 - age / life
            let spread = 1 - pow(1 - min(age / 0.9, 1), 3)
            for i in 0..<sparks {
                let angle = Double(i) / Double(sparks) * 2 * .pi + noise(burst, 5)
                let r = reach * spread * (0.8 + 0.2 * noise(burst * 97, i))
                let p = CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r + 60 * age * age)
                let dot = 3.2 * fade + 0.8
                ctx.opacity = fade
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - dot, y: p.y - dot, width: dot * 2, height: dot * 2)),
                         with: .color(color))
            }
            if age < 0.15 {
                ctx.opacity = 1 - age / 0.15
                ctx.fill(Path(ellipseIn: CGRect(x: center.x - 14, y: center.y - 14, width: 28, height: 28)), with: .color(.white))
            }
        }
        ctx.opacity = 1
    }
}

private enum Confetti {
    static let pieces = 140

    static func draw(in ctx: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        for i in 0..<pieces {
            let delay = noise(i, 1) * 2.5
            let t = time - delay
            guard t > 0 else { continue }
            let speed = 140 + 160 * noise(i, 2)
            let y = -20 + t * speed
            guard y < size.height + 20 else { continue }
            let x = size.width * noise(i, 3) + sin(t * (1.5 + 2 * noise(i, 4)) + Double(i)) * 28
            let spin = t * (2 + 4 * noise(i, 5))
            var piece = ctx
            piece.translateBy(x: x, y: y)
            piece.rotate(by: .radians(spin))
            piece.scaleBy(x: cos(spin * 1.3), y: 1)
            piece.fill(Path(CGRect(x: -4, y: -7, width: 8, height: 14)),
                       with: .color(palette[i % palette.count]))
        }
    }
}
