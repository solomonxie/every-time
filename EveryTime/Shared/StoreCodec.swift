import Foundation
import os

/// JSON for stored values. Bytes that no longer decode are moved to `<key>.corrupt` before a write, and never overwritten.
enum StoreCodec {
    static let corruptSuffix = ".corrupt"
    private static let log = Logger(subsystem: "EveryTime", category: "StoreCodec")

    static func corruptKey(_ key: String) -> String { key + corruptSuffix }
    static func isCorruptKey(_ key: String) -> Bool { key.hasSuffix(corruptSuffix) }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data?) -> T? {
        data.flatMap { try? JSONDecoder().decode(type, from: $0) }
    }

    /// Bytes to write over `current`, or nil to leave the key as it is.
    static func encode<T: Codable>(_ value: T, replacing current: Data?, key: String, in defaults: UserDefaults) -> Data? {
        let data: Data
        do {
            data = try JSONEncoder().encode(value)
        } catch {
            log.error("Not saving \(key, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
        guard let current, isUnreadable(current, as: T.self) else { return data }
        return setAside(current, key: key, in: defaults) ? data : nil
    }

    static func write<T: Codable>(_ value: T, _ key: String, to defaults: UserDefaults) {
        guard let data = encode(value, replacing: defaults.data(forKey: key), key: key, in: defaults) else { return }
        defaults.set(data, forKey: key)
    }

    private static func isUnreadable<T: Decodable>(_ data: Data, as type: T.Type) -> Bool {
        !data.isEmpty && data != Data("null".utf8) && decode(type, from: data) == nil
    }

    private static func setAside(_ data: Data, key: String, in defaults: UserDefaults) -> Bool {
        let aside = corruptKey(key)
        if let kept = defaults.data(forKey: aside), kept != data {
            log.error("Not saving \(key, privacy: .public): unreadable, and \(aside, privacy: .public) is taken")
            return false
        }
        defaults.set(data, forKey: aside)
        log.error("Moved unreadable \(key, privacy: .public) to \(aside, privacy: .public)")
        return true
    }
}
