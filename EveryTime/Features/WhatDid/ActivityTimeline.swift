import SwiftUI

/// Full-width strip of time under a fixed cursor near the right edge, so most of it shows the past. Drag to move through past days; long-press a pin for its options.
/// One canvas, redrawn only by its own drag; the page hears the cursor only when the drag ends.
struct ActivityTimeline: View {
    static let height: CGFloat = 76

    let spans: [ActivitySpan]
    /// Earliest time you can drag back to.
    let start: Date
    let now: Date
    let selected: UUID?
    /// Where the cursor settled; nil while following now.
    @Binding var cursor: Date?
    /// Jumps here when set, e.g. a range picked from History.
    @Binding var focus: Date?
    var hourWidth: CGFloat = 48
    /// Cursor position as a fraction of the width.
    var anchor: CGFloat = 0.9
    static let snap: TimeInterval = 5 * 60
    let onHoldPin: (UUID) -> Void
    @GestureState private var drag: CGFloat = 0
    @State private var width: CGFloat = 0
    @State private var holding = false

    private var center: Date {
        let base = cursor ?? now
        let moved = base.addingTimeInterval(-Double(drag / hourWidth) * 3600)
        return min(now, max(start, moved))
    }

    var body: some View {
        let center = center
        Canvas { context, size in
            draw(&context, size: size, center: center)
        }
        .frame(height: Self.height)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 6)
                .updating($drag) { value, state, _ in state = value.translation.width }
                .onEnded { value in
                    let base = cursor ?? now
                    let moved = min(now, max(start, base.addingTimeInterval(-Double(value.translation.width / hourWidth) * 3600)))
                    let snapped = Date(timeIntervalSinceReferenceDate: (moved.timeIntervalSinceReferenceDate / Self.snap).rounded() * Self.snap)
                    cursor = now.timeIntervalSince(moved) < Self.snap / 2 ? nil : min(now, snapped)
                }
        )
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .sequenced(before: DragGesture(minimumDistance: 0))
                .onChanged { value in
                    guard case .second(true, let touch?) = value, !holding else { return }
                    holding = true
                    if let pin = pin(near: touch.location.x, center: center) { onHoldPin(pin) }
                }
                .onEnded { _ in holding = false }
        )
        .onGeometryChange(for: CGFloat.self, of: \.size.width) { width = $0 }
        .onChange(of: focus) {
            guard let focus else { return }
            cursor = min(now, focus)
            self.focus = nil
        }
        .sensoryFeedback(.selection, trigger: cursor == nil)
        .accessibilityElement()
        .accessibilityLabel("Timeline at \(SleepNow.clock(center))")
    }

    private func pin(near x: CGFloat, center: Date) -> UUID? {
        let time = center.addingTimeInterval(Double((x - width * anchor) / hourWidth) * 3600)
        let tolerance = 20 / hourWidth * 3600
        return spans
            .map { ($0.id, abs($0.start.timeIntervalSince(time))) }
            .filter { $0.1 <= tolerance }
            .min { $0.1 < $1.1 }?.0
    }

    private func draw(_ context: inout GraphicsContext, size: CGSize, center: Date) {
        let hour = hourWidth
        let mid = size.width * anchor
        func x(_ date: Date) -> CGFloat { mid + CGFloat(date.timeIntervalSince(center) / 3600) * hour }
        let from = center.addingTimeInterval(-Double(mid / hour) * 3600 - 3600)
        let to = center.addingTimeInterval(Double((size.width - mid) / hour) * 3600 + 3600)
        let labelEvery = hour < 30 ? 6 : hour < 60 ? 2 : 1

        // Hour ticks and labels.
        let calendar = Calendar.current
        var tick = calendar.dateInterval(of: .hour, for: from)?.start ?? from
        while tick < to {
            let isMidnight = calendar.component(.hour, from: tick) == 0
            context.fill(Path(CGRect(x: x(tick), y: 16, width: isMidnight ? 1.5 : 1, height: 56)),
                         with: .color(.secondary.opacity(isMidnight ? 0.6 : 0.3)))
            let label = isMidnight ? tick.formatted(.dateTime.weekday(.abbreviated).day()) : tick.formatted(.dateTime.hour())
            if isMidnight || calendar.component(.hour, from: tick) % labelEvery == 0 {
                context.draw(Text(label).font(.caption2.monospacedDigit().weight(isMidnight ? .semibold : .regular))
                    .foregroundStyle(isMidnight ? Color.primary : Color.secondary),
                             at: CGPoint(x: x(tick) + 3, y: 7), anchor: .leading)
            }
            tick = tick.addingTimeInterval(3600)
        }

        // Ranges and the pins that start them.
        for span in spans where span.end > from && span.start < to {
            let left = max(-10, x(span.start)), right = min(size.width + 10, x(span.end))
            let rect = CGRect(x: left, y: 24, width: max(2, right - left - 1), height: 38)
            let shape = Path(roundedRect: rect, cornerRadius: 6)
            context.fill(shape, with: .color(span.activity.tint.opacity(span.tag == nil ? 0.22 : 0.6)))
            if span.id == selected { context.stroke(shape, with: .color(.primary), lineWidth: 2) }
            if rect.width > 40, span.tag != nil {
                context.draw(Image(systemName: span.activity.symbol), at: CGPoint(x: max(14, rect.minX + 14), y: rect.midY))
            }
            context.fill(Path(CGRect(x: x(span.start) - 1, y: 18, width: 2, height: 50)), with: .color(.primary.opacity(0.8)))
        }

        // Now.
        context.fill(Path(CGRect(x: x(now) - 1, y: 14, width: 2, height: 58)), with: .color(Theme.Tone.bad))
        context.fill(Path(ellipseIn: CGRect(x: x(now) - 4, y: 10, width: 8, height: 8)), with: .color(Theme.Tone.bad))

        // Cursor, once you've moved off now.
        if cursor != nil || drag != 0 {
            context.fill(Path(CGRect(x: mid - 0.75, y: 14, width: 1.5, height: 60)), with: .color(.accentColor))
            var arrow = Path()
            arrow.move(to: CGPoint(x: mid - 5, y: 12)); arrow.addLine(to: CGPoint(x: mid + 5, y: 12))
            arrow.addLine(to: CGPoint(x: mid, y: 18)); arrow.closeSubpath()
            context.fill(arrow, with: .color(.accentColor))
        }
    }
}
