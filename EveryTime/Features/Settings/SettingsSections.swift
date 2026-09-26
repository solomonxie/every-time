import SwiftUI

/// Backup settings as inline List sections; lives at the bottom of More.
struct SettingsSections: View {
    @ObservedObject private var backup = AutoBackup.shared
    @State private var exportDocument: BackupDocument?
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var pendingImport: BackupSnapshot?
    @State private var importError: String?
    @State private var message: String?

    private static let cloudPath = "Files → iCloud Drive → Every Time"
    fileprivate static let localPath = "Files → On My iPhone → Every Time"

    var body: some View {
        Section {
            cloudDriveRow
        } header: {
            InfoHeader(
                title: "Backup",
                info: "A copy of your cities, lunar and “since” dates, timer settings, tab bar and LeetCode history, as one small .zip. Saved once a day when something changed; iCloud Drive keeps the latest 10. It's a backup, not sync between devices. Reinstall the app and your data comes back from iCloud by itself."
            )
        } footer: {
            Text("Outlives deleting the app.")
        }
        .listRowBackground(Theme.cardFill)

        Section {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily copies")
                    Text("\(Self.localPath) · last 7 days")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "iphone").foregroundStyle(.secondary)
            }
            .frame(minHeight: 44)
        } header: {
            InfoHeader(
                title: "This iPhone",
                info: "A copy is also saved here once a day, and before every import. They go when the app does, so they're for undoing a mistake, not for a lost phone: import one to roll back."
            )
        }
        .listRowBackground(Theme.cardFill)

        Section {
            Button(action: export) {
                Label("Export backup…", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            Button { showingImporter = true } label: {
                Label("Import backup…", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .modifier(presenters)
        } footer: {
            if let message { Text(message) }
        }
        .listRowBackground(Theme.cardFill)
    }

    /// File sheets, confirmation and alert; attached to a row because sections have no single view to hang them on.
    private var presenters: BackupPresenters {
        BackupPresenters(
            exportDocument: $exportDocument,
            showingExporter: $showingExporter,
            showingImporter: $showingImporter,
            pendingImport: $pendingImport,
            importError: $importError,
            message: $message,
            restore: restore
        )
    }

    private var cloudDriveRow: some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle(isOn: $backup.isEnabled) {
                Label {
                    Text("iCloud Drive")
                } icon: {
                    Image(systemName: "icloud").foregroundStyle(.secondary)
                }
            }
            .disabled(backup.status != .ready)
            TimelineView(.everyMinute) { _ in
                Text(cloudDriveSubtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if backup.status == .driveOff {
                Text("Settings → your name → iCloud → iCloud Drive → turn on")
                    .font(.footnote)
                    .foregroundStyle(.tint)
            }
        }
    }

    /// A blocked state replaces the location line rather than appending to it.
    private var cloudDriveSubtitle: String {
        switch backup.status {
        case .notEntitled: return "This build of the app isn't signed for iCloud"
        case .driveOff: return "iCloud Drive is off on this device"
        case .notReady: return "Setting up your iCloud folder — try again shortly"
        case .ready, nil: break
        }
        if let error = backup.lastError { return "Last backup failed: \(error)" }
        guard backup.isEnabled else { return Self.cloudPath }
        if backup.isBackingUp { return "\(Self.cloudPath) · backing up…" }
        guard let lastAt = backup.lastBackupAt else { return "\(Self.cloudPath) · nothing to back up yet" }
        return "\(Self.cloudPath) · \(lastAt.formatted(.relative(presentation: .named, unitsStyle: .abbreviated)))"
    }

    private func export() {
        let snapshot = BackupSnapshot.current()
        guard !snapshot.isEmpty, let data = try? BackupArchive.make(snapshot) else {
            message = "Nothing to export yet."
            return
        }
        exportDocument = BackupDocument(data: data)
        showingExporter = true
    }

    private func restore(_ snapshot: BackupSnapshot) {
        guard LocalBackups.writeBefore("import") else {
            message = "Couldn't save a copy of the current data first, so nothing was replaced."
            return
        }
        snapshot.apply()
        message = "Restored \(snapshot.summary)."
    }

    fileprivate static func read(_ url: URL) throws -> BackupSnapshot {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { throw BackupError.unreadable }
        return try BackupArchive.read(data)
    }
}

private struct BackupPresenters: ViewModifier {
    @Binding var exportDocument: BackupDocument?
    @Binding var showingExporter: Bool
    @Binding var showingImporter: Bool
    @Binding var pendingImport: BackupSnapshot?
    @Binding var importError: String?
    @Binding var message: String?
    let restore: (BackupSnapshot) -> Void

    func body(content: Content) -> some View {
        content
            .fileExporter(
                isPresented: $showingExporter,
                document: exportDocument,
                contentType: .zip,
                defaultFilename: BackupArchiveName.base()
            ) { result in
                exportDocument = nil
                if case .failure(let error) = result { message = error.localizedDescription }
            }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.zip]) { result in
                guard case .success(let url) = result else { return }
                do {
                    pendingImport = try SettingsSections.read(url)
                } catch {
                    importError = error.localizedDescription
                }
            }
            .confirmationDialog(
                "Replace your data with this backup?",
                isPresented: Binding(get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } }),
                titleVisibility: .visible,
                presenting: pendingImport
            ) { snapshot in
                Button("Replace", role: .destructive) { restore(snapshot) }
                Button("Cancel", role: .cancel) {}
            } message: { snapshot in
                Text("\(snapshot.summary)\n\nWhat's here now is saved to \(SettingsSections.localPath) first.")
            }
            .alert(
                "Can't import this file",
                isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } }),
                presenting: importError
            ) { _ in
                Button("OK") {}
            } message: { Text($0) }
    }
}

/// Section label with an ⓘ popover holding the explanation.
private struct InfoHeader: View {
    let title: String
    let info: String
    @State private var showing = false

    var body: some View {
        SectionLabel(title: title) {
            Button { showing = true } label: {
                Image(systemName: "info.circle")
                    .font(.footnote)
                    .frame(minWidth: 28, minHeight: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("About \(title)")
            .popover(isPresented: $showing) {
                Text(info)
                    .font(.footnote)
                    .textCase(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(idealWidth: 300)
                    .padding()
                    .presentationCompactAdaptation(.popover)
            }
        }
        .textCase(nil)
    }
}

#Preview {
    List { SettingsSections() }
}
