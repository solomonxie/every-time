import Foundation

/// Which App Store this install targets, set at build time (`make <target> STORE=cn`).
enum StoreRegion: String {
    case us, cn

    static let current = StoreRegion(rawValue: Bundle.main.object(forInfoDictionaryKey: "AppStoreRegion") as? String ?? "") ?? .us
}
