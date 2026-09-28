import SwiftUI

/// Tonight's bed and wake: drag the dial, or tap a bedtime that wakes you between cycles.
/// Changes apply right away and last one night.
struct NightEditor: View {
    @Binding var hours: NightDial.Hours
    let usual: NightDial.Hours

    private var isUsual: Bool { hours == usual }

    var body: some View {
        VStack(spacing: 20) {
            HStack(alignment: .top) {
                readout("Bed", symbol: "bed.double.fill", minutes: hours.bed) { hours.moving(bed: $0) }
                Spacer()
                readout("Wake up", symbol: "alarm.fill", minutes: hours.wake) { hours.moving(wake: $0) }
                    .multilineTextAlignment(.trailing)
            }
            NightDial(hours: $hours)
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 8)
            bedtimes
            Button {
                withAnimation(.snappy) { hours = usual }
            } label: {
                Label("Back to usual · \(usual.bed.timeOfDayText) – \(usual.wake.timeOfDayText)",
                      systemImage: "arrow.uturn.backward")
            }
            .buttonStyle(.soft)
            .disabled(isUsual)
            .opacity(isUsual ? 0 : 1)
            Text("For tonight only. Your usual hours come back tomorrow.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Theme.padding)
        .padding(.vertical, 12)
        .animation(.snappy, value: hours)
        .navigationTitle("Tonight")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func readout(_ title: String, symbol: String, minutes: Int, move: @escaping (Int) -> NightDial.Hours) -> some View {
        VStack(alignment: title == "Bed" ? .leading : .trailing, spacing: 2) {
            Label(title, systemImage: symbol)
                .font(.label)
                .foregroundStyle(.secondary)
            Text(minutes.timeOfDayText)
                .font(.clock(34, weight: .regular))
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
        .accessibilityAdjustableAction { direction in
            let step = direction == .increment ? NightDial.step : -NightDial.step
            hours = move(minutes + step)
        }
    }

    /// Bedtimes for the chosen wake that end on a whole cycle.
    private var bedtimes: some View {
        let fallAsleep = Int(SleepSuggestion.fallAsleepTime / 60), cycle = Int(SleepSuggestion.cycleLength / 60)
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Bedtimes that end on a cycle")
            HStack(spacing: 8) {
                ForEach([6, 5, 4], id: \.self) { cycles in
                    let bed = NightDial.wrap(hours.wake - fallAsleep - cycles * cycle)
                    let isOn = hours.bed == bed
                    Button {
                        hours = NightDial.Hours(bed: bed, wake: hours.wake)
                    } label: {
                        VStack(spacing: 2) {
                            Text(bed.timeOfDayText)
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .monospacedDigit()
                            Text("\(cycles) cycles")
                                .font(.caption2)
                                .foregroundStyle(isOn ? Color.white.opacity(0.85) : .secondary)
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(isOn ? Color.white : .primary)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(isOn ? AnyShapeStyle(Color.indigo) : AnyShapeStyle(Theme.cardFill),
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
        }
    }
}
