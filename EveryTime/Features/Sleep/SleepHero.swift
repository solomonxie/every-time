import SwiftUI

/// What one tap does: in bed at `bed` (now or later), up at `wake`, as a nap or a night.
struct WakeChoice: Equatable {
    let now: Date
    let bed: Date
    let wake: Date

    /// A bed on the nearest mark, up to half a step ahead, still starts now.
    var isNow: Bool { bed.timeIntervalSince(now) <= Double(SleepRing.step) * 30 }
    var minutes: Int { max(1, Int((wake.timeIntervalSince(bed) / 60).rounded())) }
    var length: TimeInterval { Double(minutes) * 60 }
    var isNap: Bool { length < Nap.nightLength }
    var fit: WakeFit { WakeFit.of(length: length, isNap: isNap) }
    var cycles: Double { max(0, length - SleepSuggestion.fallAsleepTime) / SleepSuggestion.cycleLength }

    var button: String {
        isNow ? "\(isNap ? "Nap" : "Sleep") now · up at \(SleepNow.clock(wake))"
            : "Start schedule · bed \(SleepNow.clock(bed))"
    }
    var symbol: String { !isNow ? "bed.double.fill" : isNap ? "cup.and.saucer.fill" : "moon.zzz.fill" }

    /// "5 cycles · Wakes between cycles".
    var fitLine: String {
        let what = isNap ? "\(minutes)-min nap"
            : "\(cycles.formatted(.number.precision(.fractionLength(cycles.rounded() == cycles ? 0 : 1)))) cycles"
        return "\(ActivityLog.duration(length)) · \(what) · \(fit.text(isNap: isNap))"
    }
}

/// A nap is one icon with a length from a wheel; a sleep has its own span on the ring.
enum SleepKind: String, CaseIterable {
    case nap = "Nap", sleep = "Sleep"
    static var napMinutes: ClosedRange<Int> { 5...max(90, NapAdvice.longMinutes) }
}

/// Idle top of the Sleep page: bed and wake readouts (tap for a wheel), the ring, wake chips and the verdict.
struct SleepHero: View {
    let now: Date
    let sleepNow: SleepNow
    let choice: WakeChoice
    /// nil = now.
    @Binding var bed: Date?
    /// nil = the pick for now.
    @Binding var wake: Date?

    @Binding var kind: SleepKind
    @Binding var napMinutes: Int
    var napBlockedTip: String?

    private enum End { case bed, wake }
    @State private var open: End?
    @State private var editsNap = false
    @State private var showsNapTip = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if kind == .nap {
                HStack(spacing: 8) {
                    Button { editsNap = true } label: { stat("cup.and.saucer.fill", "Nap", "\(napMinutes) min", "Tap for exact") }
                        .buttonStyle(.plain)
                    stat("alarm.fill", "Wake up", SleepNow.clock(choice.wake), "Today")
                }
            } else {
                HStack(spacing: 8) {
                    readout(.bed, "bed.double.fill", "Bedtime", choice.bed)
                    readout(.wake, "alarm.fill", "Wake up", choice.wake)
                }
            }
            if kind == .sleep, let open {
                MinuteWheel(date: wheel(open))
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
                    .clipped()
            }
            Label(choice.fitLine, systemImage: choice.fit == .good ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(choice.fit.color)
                .contentTransition(.numericText())
            SleepRing(now: now, bed: kind == .nap ? nil : ringBed, wake: kind == .nap ? nil : ringWake,
                      nap: kind == .nap ? napMinutes : nil, minLength: Int(Nap.nightLength / 60))
                .frame(maxWidth: 300)
                .frame(maxWidth: .infinity)
            kindTiles
            if kind == .nap { napChips } else { chips }
            Text(verdict)
                .font(.footnote)
                .foregroundStyle(sleepNow.zone == .evening && sleepNow.sleepOptions.first?.level == .high ? Theme.Tone.bad : .secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .animation(.snappy, value: choice)
        .animation(.snappy, value: open)
        .sheet(isPresented: $editsNap) {
            NavigationStack {
                Picker("Nap length", selection: $napMinutes) {
                    ForEach(Array(stride(from: SleepKind.napMinutes.lowerBound, through: SleepKind.napMinutes.upperBound, by: 5)), id: \.self) {
                        Text("\($0) min").tag($0)
                    }
                }
                .pickerStyle(.wheel)
                .navigationTitle("Nap length")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { editsNap = false } } }
            }
            .presentationDetents([.height(300)])
        }
    }

    private var kindTiles: some View {
        HStack(spacing: 10) {
            tile(.nap, "cup.and.saucer.fill", "\(napMinutes) min")
            tile(.sleep, "moon.zzz.fill", kind == .sleep ? "up \(SleepNow.clock(choice.wake))" : "bed & alarm")
        }
    }

    private func tile(_ tile: SleepKind, _ symbol: String, _ detail: String) -> some View {
        let picked = kind == tile
        let blocked = tile == .nap && napBlockedTip != nil
        return Button { if blocked { showsNapTip = true } else { kind = tile } } label: {
            HStack(spacing: 10) {
                Image(systemName: symbol).font(.title2)
                VStack(alignment: .leading, spacing: 1) {
                    Text(tile.rawValue).font(.headline)
                    Text(detail).font(.caption).monospacedDigit().opacity(0.8)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 64)
            .foregroundStyle(picked ? Color.white : .primary)
            .background(picked ? AnyShapeStyle(Color.indigo) : AnyShapeStyle(Theme.cardFill), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .opacity(blocked ? 0.4 : 1)
        }
        .buttonStyle(.plain)
        .alert("Nap unavailable", isPresented: $showsNapTip) { Button("OK", role: .cancel) {} } message: { Text(napBlockedTip ?? "") }
        .sensoryFeedback(.selection, trigger: kind)
        .accessibilityAddTraits(picked ? .isSelected : [])
    }

    private func stat(_ symbol: String, _ title: String, _ value: String, _ caption: String) -> some View {
        VStack(spacing: 2) {
            Label(title.uppercased(), systemImage: symbol).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.clock(30, weight: .semibold)).contentTransition(.numericText())
            Text(caption).font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var napChips: some View {
        HStack(spacing: 8) {
            ForEach([10, 20, 30, 45, 60, NapAdvice.longMinutes], id: \.self) { minutes in
                let picked = napMinutes == minutes
                Button { napMinutes = minutes } label: {
                    Text("\(minutes)")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(picked ? Color.white : .primary)
                        .background(picked ? AnyShapeStyle(Color.indigo) : AnyShapeStyle(Theme.cardFill), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(minutes) minute nap")
            }
        }
    }

    private func readout(_ end: End, _ symbol: String, _ title: String, _ time: Date) -> some View {
        Button { open = open == end ? nil : end } label: {
            VStack(spacing: 2) {
                Label(title.uppercased(), systemImage: symbol).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Text(SleepNow.clock(time)).font(.clock(30, weight: .semibold)).contentTransition(.numericText())
                    Image(systemName: "chevron.down").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                        .rotationEffect(.degrees(open == end ? 180 : 0))
                }
                Text(end == .bed && choice.isNow ? "Now" : Calendar.current.isDateInToday(time) ? "Today" : "Tomorrow")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) \(SleepNow.clock(time)), tap to pick an exact time")
    }

    private var ringBed: Binding<Date> {
        Binding(get: { choice.bed }, set: { bed = $0 <= SleepRing.snap(now) ? nil : $0 })
    }

    private var ringWake: Binding<Date> {
        Binding(get: { choice.wake }, set: { wake = $0 })
    }

    /// The wheel gives a clock time; it lands on the right side of midnight, after now (bed) or after bed (wake).
    private func wheel(_ end: End) -> Binding<Date> {
        Binding(get: { end == .bed ? choice.bed : choice.wake }, set: { picked in
            let floor = end == .bed ? now : choice.bed.addingTimeInterval(Nap.nightLength)
            var date = picked
            if date < floor { date = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date }
            if date.timeIntervalSince(floor) > Double(SleepRing.lengths.upperBound) * 60 {
                date = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
            }
            date = SleepRing.snap(max(floor, date))
            if end == .bed {
                bed = date.timeIntervalSince(now) < 60 ? nil : date
                if choice.wake.timeIntervalSince(date) < Nap.nightLength { wake = nil }
            } else {
                wake = date
            }
        })
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 8) {
                ForEach(sleepNow.options.filter { $0.time.timeIntervalSince(choice.bed) >= Nap.nightLength - 60 }) { option in
                    let time = SleepRing.snap(option.time)
                    let isPicked = abs(time.timeIntervalSince(choice.wake)) < 60
                    Button {
                        wake = time
                    } label: {
                        VStack(spacing: 4) {
                            HStack(spacing: 5) {
                                if !isPicked {
                                    Circle().fill(option.level.tint).frame(width: 7, height: 7)
                                }
                                Text(SleepNow.clock(time))
                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                    .monospacedDigit()
                            }
                            .padding(.horizontal, 12)
                            .frame(minHeight: 36)
                            .foregroundStyle(isPicked ? Color.white : .primary)
                            .background(isPicked ? AnyShapeStyle(Color.indigo) : AnyShapeStyle(Theme.cardFill), in: Capsule())
                            Text(option.caption)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Up at \(SleepNow.clock(time)), \(option.caption)")
                }
            }
            .padding(.horizontal, 2)
        }
        .scrollClipDisabled()
    }

    private var verdict: String {
        let (headline, reason) = sleepNow.verdict
        var text = "\(headline) — \(reason.prefix(1).lowercased() + reason.dropFirst())"
        if let tip = sleepNow.tip { text += " \(tip)" }
        return text
    }
}
