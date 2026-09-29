import SwiftUI

/// What the What did log says about your sleep: up since, last night, and your typical hours.
struct LoggedDayCard: View {
    let log: ActivityLog
    let now: Date

    var body: some View {
        let up = log.upSince(at: now)
        let night = log.nights(at: now).first.flatMap { now.timeIntervalSince($0.end) < 86_400 ? $0 : nil }
        let typical = log.typical(at: now)
        let asleep = log.current?.tag == Activity.sleep.id ? log.current?.time : nil
        Card {
            if let asleep {
                row(Activity.sleep, "Asleep since \(SleepNow.clock(asleep))")
            } else if let up {
                row(Activity.wake, "Up since \(SleepNow.clock(up)) · \(ActivityLog.duration(now.timeIntervalSince(up))) awake")
            }
            if let night {
                row(Activity.sleep, "Last night \(SleepNow.clock(night.start)) – \(SleepNow.clock(night.end)) · \(ActivityLog.duration(night.duration))")
            }
            if typical.nights >= 2, let bed = typical.bed, let wake = typical.wake {
                Text("Usually \(clock(bed)) – \(clock(wake)) lately, from ^[\(typical.nights) night](inflect: true).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    static func hasContent(_ log: ActivityLog, now: Date) -> Bool {
        log.upSince(at: now) != nil || log.current?.tag == Activity.sleep.id || !log.nights(at: now).isEmpty
    }

    private func row(_ activity: Activity, _ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: activity.symbol).foregroundStyle(activity.tint).frame(width: 22)
            Text(text).font(.subheadline)
        }
    }

    private func clock(_ minutes: Int) -> String {
        SleepNow.clock(Calendar.current.clockTime(minutes: minutes, of: now))
    }
}
