import Foundation

/// Ids derived from APP_BUNDLE_ID via Info.plist, so app and widget agree without hardcoding them.
enum AppIdentifier {
    /// group.$(APP_BUNDLE_ID)
    static let appGroup = infoString("AppGroupIdentifier")
    /// iCloud.$(APP_BUNDLE_ID)
    static let iCloudContainer = infoString("ICloudContainerIdentifier")

    private static func infoString(_ key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String, !value.isEmpty else {
            preconditionFailure("\(key) missing from Info.plist")
        }
        return value
    }
}
