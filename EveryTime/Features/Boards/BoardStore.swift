import EventKit
import SwiftUI

/// Reminders/Calendar access for Boards. Cards are read fresh from EventKit; `revision` bumps whenever
/// the store changes (here or in Reminders), so views reload with `.task(id: store.revision)`.
@MainActor
@Observable
final class BoardStore {
    enum Access { case unknown, granted, denied }

    struct ListInfo: Identifiable, Hashable {
        let id: String
        let title: String
        let color: Color
        let isWritable: Bool
    }

    struct Milestone: Identifiable, Hashable {
        let id: String
        let title: String
        let date: Date
    }

    static let shared = BoardStore()
    static let doneWindow: TimeInterval = 90 * 86_400

    private let store = EKEventStore()
    private(set) var access: Access = .unknown
    private(set) var revision = 0
    private(set) var configs: [BoardConfig] = []

    private init() {
        access = Self.currentAccess
        loadConfigs()
        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.changed() }
        }
    }

    private static var currentAccess: Access {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .fullAccess: .granted
        case .denied, .restricted, .writeOnly: .denied
        default: .unknown
        }
    }

    func requestAccess() async {
        let granted = (try? await store.requestFullAccessToReminders()) ?? false
        access = granted ? .granted : .denied
        changed()
    }

    /// Re-read after a restore or a trip to Settings.
    func refresh() {
        access = Self.currentAccess
        loadConfigs()
        changed()
    }

    private func changed() { revision += 1 }

    // MARK: Boards

    func config(for listID: String) -> BoardConfig? { configs.first { $0.listID == listID } }

    func save(_ config: BoardConfig) {
        if let index = configs.firstIndex(where: { $0.listID == config.listID }) {
            configs[index] = config
        } else {
            configs.append(config)
        }
        persistConfigs()
    }

    func removeBoard(_ listID: String) {
        configs.removeAll { $0.listID == listID }
        persistConfigs()
    }

    func moveBoards(from offsets: IndexSet, to destination: Int) {
        configs.move(fromOffsets: offsets, toOffset: destination)
        persistConfigs()
    }

    private func loadConfigs() {
        configs = UserDefaults.standard.data(forKey: BoardConfig.storageKey)
            .flatMap { try? JSONDecoder().decode([BoardConfig].self, from: $0) } ?? []
    }

    private func persistConfigs() {
        UserDefaults.standard.set(try? JSONEncoder().encode(configs), forKey: BoardConfig.storageKey)
        changed()
    }

    // MARK: Lists

    func lists() -> [ListInfo] {
        store.calendars(for: .reminder).map(Self.info).sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func list(_ id: String) -> ListInfo? {
        store.calendar(withIdentifier: id).map(Self.info)
    }

    func createList(named title: String) throws -> ListInfo {
        let list = EKCalendar(for: .reminder, eventStore: store)
        list.title = title
        guard let source = store.defaultCalendarForNewReminders()?.source ?? store.sources.first(where: { $0.sourceType == .local }) else {
            throw BoardError.noAccount
        }
        list.source = source
        try store.saveCalendar(list, commit: true)
        return Self.info(list)
    }

    private static func info(_ calendar: EKCalendar) -> ListInfo {
        ListInfo(id: calendar.calendarIdentifier, title: calendar.title,
                 color: Color(cgColor: calendar.cgColor), isWritable: calendar.allowsContentModifications)
    }

    // MARK: Cards

    /// Open cards plus those completed in the last 90 days.
    func cards(in listID: String, now: Date = .now) async -> [BoardCard] {
        guard access == .granted, let list = store.calendar(withIdentifier: listID) else { return [] }
        let open = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: [list])
        let done = store.predicateForCompletedReminders(withCompletionDateStarting: now.addingTimeInterval(-Self.doneWindow),
                                                        ending: now.addingTimeInterval(60), calendars: [list])
        async let a = fetch(open)
        async let b = fetch(done)
        return await a + b
    }

    private func fetch(_ predicate: NSPredicate) async -> [BoardCard] {
        await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: (reminders ?? []).map(Self.card))
            }
        }
    }

    private static func card(_ reminder: EKReminder) -> BoardCard {
        let trailer = CardTrailer.parse(reminder.notes)
        return BoardCard(id: reminder.calendarItemIdentifier, externalID: reminder.calendarItemExternalIdentifier,
                    title: reminder.title ?? "", notes: trailer.body, column: trailer.column, points: trailer.points,
                    due: reminder.dueDateComponents, priority: reminder.priority, isCompleted: reminder.isCompleted,
                    completedAt: reminder.completionDate, createdAt: reminder.creationDate)
    }

    /// Cards per column, Done last (newest first); also records today's flow snapshot.
    func grouped(_ cards: [BoardCard], by config: BoardConfig) -> [(column: BoardColumn?, cards: [BoardCard])] {
        var result: [(BoardColumn?, [BoardCard])] = config.columns.map { column in
            (column, cards.filter { config.column(of: $0)?.id == column.id }.sorted(by: Self.openOrder))
        }
        result.append((nil, cards.filter(\.isCompleted).sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }))
        BoardFlow.record(result.map { ($0.0?.name ?? BoardConfig.doneName, $0.1.count) }, board: config.listID)
        return result
    }

    private static func openOrder(_ a: BoardCard, _ b: BoardCard) -> Bool {
        switch (a.dueDate, b.dueDate) {
        case let (x?, y?) where x != y: x < y
        case (_?, nil): true
        case (nil, _?): false
        default: (a.createdAt ?? .distantPast) < (b.createdAt ?? .distantPast)
        }
    }

    // MARK: Writes

    /// `column == nil` means Done.
    func move(_ card: BoardCard, to column: BoardColumn?) throws {
        try edit(card.id) { reminder in
            if let column {
                reminder.isCompleted = false
                reminder.notes = CardTrailer.write(body: card.notes, column: column.name, points: card.points)
            } else {
                reminder.isCompleted = true
            }
        }
    }

    func save(_ card: BoardCard, column: BoardColumn?) throws {
        try edit(card.id) { reminder in apply(card, column: column, to: reminder) }
    }

    @discardableResult
    func create(_ card: BoardCard, in listID: String, column: BoardColumn?) throws -> String {
        guard let list = store.calendar(withIdentifier: listID) else { throw BoardError.listGone }
        let reminder = EKReminder(eventStore: store)
        reminder.calendar = list
        apply(card, column: column, to: reminder)
        try store.save(reminder, commit: true)
        return reminder.calendarItemIdentifier
    }

    func delete(_ card: BoardCard) throws {
        guard let reminder = store.calendarItem(withIdentifier: card.id) as? EKReminder else { throw BoardError.cardGone }
        try store.remove(reminder, commit: true)
    }

    /// Rewrites the trailer on every card in `from`; returns how many changed.
    @discardableResult
    func renameColumn(in listID: String, from old: String, to new: String) async throws -> Int {
        let affected = await cards(in: listID).filter { !$0.isCompleted && $0.column?.caseInsensitiveCompare(old) == .orderedSame }
        for card in affected {
            guard let reminder = store.calendarItem(withIdentifier: card.id) as? EKReminder else { continue }
            reminder.notes = CardTrailer.write(body: card.notes, column: new, points: card.points)
            try store.save(reminder, commit: false)
        }
        try store.commit()
        return affected.count
    }

    private func apply(_ card: BoardCard, column: BoardColumn?, to reminder: EKReminder) {
        reminder.title = card.title
        reminder.dueDateComponents = card.due
        reminder.priority = card.priority
        reminder.notes = CardTrailer.write(body: card.notes, column: column?.name ?? card.column, points: card.points)
        reminder.isCompleted = column == nil
    }

    private func edit(_ id: String, _ change: (EKReminder) -> Void) throws {
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else { throw BoardError.cardGone }
        change(reminder)
        try store.save(reminder, commit: true)
    }

    // MARK: Milestones (calendar events)

    var eventAccess: Access {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: .granted
        case .denied, .restricted, .writeOnly: .denied
        default: .unknown
        }
    }

    func requestEventAccess() async {
        _ = try? await store.requestFullAccessToEvents()
        changed()
    }

    func eventCalendars() -> [ListInfo] {
        guard eventAccess == .granted else { return [] }
        return store.calendars(for: .event).filter(\.allowsContentModifications).map(Self.info)
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func milestones(in calendarID: String?, around now: Date = .now) -> [Milestone] {
        guard eventAccess == .granted, let calendarID, let calendar = store.calendar(withIdentifier: calendarID) else { return [] }
        let predicate = store.predicateForEvents(withStart: now.addingTimeInterval(-180 * 86_400),
                                                 end: now.addingTimeInterval(365 * 86_400), calendars: [calendar])
        return store.events(matching: predicate)
            .map { Milestone(id: $0.eventIdentifier ?? UUID().uuidString, title: $0.title ?? "", date: $0.startDate) }
            .sorted { $0.date < $1.date }
    }

    func addMilestone(_ title: String, on date: Date, calendarID: String) throws {
        guard let calendar = store.calendar(withIdentifier: calendarID) else { throw BoardError.listGone }
        let event = EKEvent(eventStore: store)
        event.calendar = calendar
        event.title = title
        event.isAllDay = true
        event.startDate = Calendar.current.startOfDay(for: date)
        event.endDate = event.startDate
        try store.save(event, span: .thisEvent, commit: true)
    }
}

enum BoardError: LocalizedError {
    case listGone, cardGone, noAccount

    var errorDescription: String? {
        switch self {
        case .listGone: "That list or calendar is gone."
        case .cardGone: "That reminder is gone — it may have been deleted in Reminders."
        case .noAccount: "No Reminders account to create a list in."
        }
    }
}

/// Daily column counts per board (`boards.flow`), the only history EventKit can't give.
enum BoardFlow {
    typealias Day = [String: Int]

    static func record(_ counts: [(String, Int)], board: String, on date: Date = .now) {
        var all = load()
        let key = dayKey(date)
        var days = all[board] ?? [:]
        let today = Dictionary(counts, uniquingKeysWith: +)
        guard days[key] != today else { return }
        days[key] = today
        all[board] = days.filter { $0.key >= dayKey(date.addingTimeInterval(-366 * 86_400)) }
        UserDefaults.standard.set(try? JSONEncoder().encode(all), forKey: BoardConfig.flowKey)
    }

    static func history(board: String) -> [(date: Date, counts: Day)] {
        (load()[board] ?? [:]).compactMap { key, counts in formatter.date(from: key).map { ($0, counts) } }
            .sorted { $0.date < $1.date }
    }

    private static func load() -> [String: [String: Day]] {
        UserDefaults.standard.data(forKey: BoardConfig.flowKey)
            .flatMap { try? JSONDecoder().decode([String: [String: Day]].self, from: $0) } ?? [:]
    }

    private static func dayKey(_ date: Date) -> String { formatter.string(from: date) }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
