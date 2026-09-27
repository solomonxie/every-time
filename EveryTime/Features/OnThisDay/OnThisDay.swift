import Foundation

/// One day of Wikipedia's "On this day" feed.
struct OnThisDay: Codable, Equatable {
    var selected: [Entry] = []
    var events: [Entry] = []
    var births: [Entry] = []
    var deaths: [Entry] = []
    var holidays: [Entry] = []

    struct Entry: Codable, Hashable {
        var text: String
        var year: Int?
        var pages: [Page] = []
    }

    struct Page: Codable, Hashable {
        var title: String
        var url: URL
    }

    enum Section: String, CaseIterable, Identifiable {
        case selected = "Selected"
        case events = "Events"
        case births = "Births"
        case deaths = "Deaths"
        case holidays = "Holidays"
        var id: String { rawValue }
    }

    subscript(section: Section) -> [Entry] {
        switch section {
        case .selected: selected
        case .events: events
        case .births: births
        case .deaths: deaths
        case .holidays: holidays
        }
    }

    var isEmpty: Bool { Section.allCases.allSatisfy { self[$0].isEmpty } }
}

extension OnThisDay {
    static func url(month: Int, day: Int) -> URL {
        URL(string: String(format: "https://en.wikipedia.org/api/rest_v1/feed/onthisday/all/%02d/%02d", month, day))!
    }

    static func decodeFeed(_ data: Data) throws -> OnThisDay {
        let feed = try JSONDecoder().decode(Feed.self, from: data)
        return OnThisDay(
            selected: feed.selected?.map(\.entry) ?? [],
            events: feed.events?.map(\.entry) ?? [],
            births: feed.births?.map(\.entry) ?? [],
            deaths: feed.deaths?.map(\.entry) ?? [],
            holidays: feed.holidays?.map(\.entry) ?? []
        )
    }

    private struct Feed: Decodable {
        var selected, events, births, deaths, holidays: [FeedEntry]?
    }

    private struct FeedEntry: Decodable {
        var text: String
        var year: Int?
        var pages: [FeedPage]?

        var entry: Entry {
            Entry(text: text, year: year, pages: (pages ?? []).compactMap(\.page))
        }
    }

    private struct FeedPage: Decodable {
        var normalizedtitle: String?
        var titles: Titles?
        var content_urls: ContentURLs?

        struct Titles: Decodable { var normalized: String? }
        struct ContentURLs: Decodable { var mobile: Link?; var desktop: Link? }
        struct Link: Decodable { var page: URL? }

        var page: Page? {
            guard let url = content_urls?.mobile?.page ?? content_urls?.desktop?.page,
                  let title = titles?.normalized ?? normalizedtitle else { return nil }
            return Page(title: title, url: url)
        }
    }
}

/// Fetches days from Wikipedia, keeping the last copy of each MM/DD in memory and in Caches.
@Observable @MainActor
final class OnThisDayStore {
    enum Phase: Equatable {
        case loading
        case loaded(OnThisDay)
        case failed(String)
    }

    private(set) var phase: Phase = .loading
    /// Set when a refresh failed and the shown day is a saved copy.
    private(set) var savedCopyDate: Date?

    private var memory: [String: Cached] = [:]
    private var currentKey = ""
    private static let refreshAfter: TimeInterval = 24 * 3600

    private struct Cached: Codable {
        var fetchedAt: Date
        var day: OnThisDay
    }

    func load(month: Int, day: Int, force: Bool = false) async {
        let key = String(format: "%02d-%02d", month, day)
        currentKey = key
        let cached = memory[key] ?? Self.readDisk(key)
        memory[key] = cached
        savedCopyDate = nil
        if let cached {
            phase = .loaded(cached.day)
            if !force, Date.now.timeIntervalSince(cached.fetchedAt) < Self.refreshAfter { return }
        } else {
            phase = .loading
        }

        do {
            let fresh = Cached(fetchedAt: .now, day: try await Self.fetch(month: month, day: day))
            memory[key] = fresh
            Self.writeDisk(fresh, key: key)
            if key == currentKey { phase = .loaded(fresh.day) }
        } catch {
            if key != currentKey || Task.isCancelled || (error as? URLError)?.code == .cancelled { return }
            if let cached {
                savedCopyDate = cached.fetchedAt
            } else {
                phase = .failed(Self.message(for: error))
            }
        }
    }

    private static func fetch(month: Int, day: Int) async throws -> OnThisDay {
        var request = URLRequest(url: OnThisDay.url(month: month, day: day), timeoutInterval: 20)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try OnThisDay.decodeFeed(data)
    }

    private static let userAgent: String = {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        return "EveryTime/\(version) (iOS; https://github.com/solomonxie/every-time)"
    }()

    private static func message(for error: Error) -> String {
        if error is DecodingError { return "Wikipedia sent something unexpected." }
        switch (error as? URLError)?.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
            return "You're offline. Days you've opened before stay available."
        case .timedOut:
            return "Wikipedia took too long to answer."
        default:
            return "Couldn't reach Wikipedia."
        }
    }

    private static let folder = URL.cachesDirectory.appending(path: "OnThisDay", directoryHint: .isDirectory)

    private static func readDisk(_ key: String) -> Cached? {
        guard let data = try? Data(contentsOf: folder.appending(path: "\(key).json")) else { return nil }
        return try? JSONDecoder().decode(Cached.self, from: data)
    }

    private static func writeDisk(_ cached: Cached, key: String) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? JSONEncoder().encode(cached).write(to: folder.appending(path: "\(key).json"), options: .atomic)
    }
}
