import SwiftUI

/// Every tool in the app; any 1–4 can be pinned to the tab bar, all are listed in More.
enum AppTool: String, CaseIterable, Identifiable, Hashable {
    case world, sleep, lunar
    case stopwatch, interview, rehearsal, leetcode, countdown
    case since, waitTimes, unixTime, converter, cron

    static let defaultPins: [AppTool] = [.world, .sleep, .lunar]
    static let maxPins = 4

    enum Group: String, CaseIterable, Identifiable {
        case main = "Main"
        case timers = "Timers"
        case dates = "Dates"
        case developer = "Developer"
        var id: String { rawValue }
        var tools: [AppTool] { AppTool.allCases.filter { $0.group == self } }
    }

    var id: String { rawValue }

    var group: Group {
        switch self {
        case .world, .sleep, .lunar: .main
        case .stopwatch, .interview, .rehearsal, .leetcode, .countdown: .timers
        case .since, .waitTimes: .dates
        case .unixTime, .converter, .cron: .developer
        }
    }

    var title: String {
        switch self {
        case .world: "World"
        case .sleep: "Sleep"
        case .lunar: "Lunar"
        case .stopwatch: "Stopwatch"
        case .interview: "Interview"
        case .rehearsal: "Rehearsal"
        case .leetcode: "LeetCode"
        case .countdown: "Countdown"
        case .since: "Important events"
        case .waitTimes: "Wait times"
        case .unixTime: "Unix timestamp"
        case .converter: "Timestamp converter"
        case .cron: "Cron parser"
        }
    }

    /// Short label that fits under a tab bar icon.
    var tabTitle: String {
        switch self {
        case .since: "Events"
        case .waitTimes: "Waits"
        case .unixTime: "Unix"
        case .converter: "Convert"
        case .cron: "Cron"
        default: title
        }
    }

    var symbol: String {
        switch self {
        case .world: "globe"
        case .sleep: "moon.stars"
        case .lunar: "calendar"
        case .stopwatch: "stopwatch"
        case .interview: "mic"
        case .rehearsal: "arrow.counterclockwise"
        case .leetcode: "chevron.left.forwardslash.chevron.right"
        case .countdown: "hourglass.bottomhalf.filled"
        case .since: "star.circle"
        case .waitTimes: "hourglass"
        case .unixTime: "number"
        case .converter: "arrow.left.arrow.right"
        case .cron: "calendar.badge.clock"
        }
    }

    /// The tool's screen, without a NavigationStack (pushed from More).
    @ViewBuilder
    var destination: some View {
        switch self {
        case .world: WorldView()
        case .sleep: SleepView()
        case .lunar: LunarCalendarView()
        case .stopwatch, .interview, .rehearsal, .leetcode: TimerToolView(tool: self)
        case .countdown: CountdownListView()
        case .since: ImportantEventsView()
        case .waitTimes: WaitingView()
        case .unixTime: UnixTimestampView()
        case .converter: TimestampConverterView()
        case .cron: CronParserView()
        }
    }

    /// The tool's screen as a tab root.
    var tab: some View {
        NavigationStack { destination }
    }
}

extension AppTool {
    /// Stored as JSON raw values (`@Stored`) so backups carry them; bad or empty lists fall back to the defaults.
    static func pins(from raw: [String]) -> [AppTool] {
        var seen = Set<AppTool>()
        let tools = raw.compactMap(AppTool.init(rawValue:)).filter { seen.insert($0).inserted }
        return tools.isEmpty ? defaultPins : Array(tools.prefix(maxPins))
    }
}

/// Timer screens bound to the shared TimerStore and their stored settings.
private struct TimerToolView: View {
    let tool: AppTool
    @Environment(TimerStore.self) private var timers
    @Stored(TimerStore.interviewMinutesKey) private var interviewMinutes = TimerStore.defaultInterviewMinutes
    @Stored(TimerStore.rehearsalMinutesKey) private var rehearsalMinutes = TimerStore.defaultRehearsalMinutes
    @Stored(TimerStore.leetcodeHistoryKey) private var history: [TimerSession] = []

    var body: some View {
        switch tool {
        case .interview:
            CountdownView(kind: .interview, clock: timers.interview, minutes: $interviewMinutes)
        case .rehearsal:
            CountdownView(kind: .rehearsal, clock: timers.rehearsal, minutes: $rehearsalMinutes, step: 1)
        case .leetcode:
            LeetCodeView(model: timers.leetcode, history: $history)
        default:
            StopwatchView(model: timers.stopwatch)
        }
    }
}
