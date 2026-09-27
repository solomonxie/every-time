import Foundation

@MainActor
enum BackupRestore {
    enum Failure: LocalizedError {
        case couldNotSaveCurrent
        var errorDescription: String? { "Couldn't save a copy of the current data first, so nothing was replaced." }
    }

    /// What's here now goes to This iPhone first; nothing is replaced if that copy fails.
    static func replace(with snapshot: BackupSnapshot, before operation: String) throws {
        guard LocalBackups.writeBefore(operation) else { throw Failure.couldNotSaveCurrent }
        snapshot.apply()
        JetLagNotifications.reschedule()
        ImportantEventNotifications.reschedule()
        CountdownNotifications.reschedule()
        LunarNotifications.reschedule()
        GlancePublisher.shared.publish()
    }
}
