import SwiftUI

enum BackupTier {
    case cloud, local

    var title: String { self == .cloud ? "iCloud Drive" : "This iPhone" }
    var path: String { self == .cloud ? "Files → iCloud Drive → Every Time" : "Files → On My iPhone → Every Time" }

    func files() async throws -> [BackupFile] {
        self == .cloud ? try await CloudDrive.files() : LocalBackups.files()
    }

    func snapshot(of file: BackupFile) async throws -> BackupSnapshot {
        let data = self == .cloud ? await CloudDrive.data(of: file) : try? Data(contentsOf: file.url)
        guard let data else { throw BackupError.unreadable }
        return try BackupArchive.read(data)
    }
}

/// Every archive in one tier, newest first, each with what's inside.
struct BackupListView: View {
    let tier: BackupTier
    @ObservedObject private var backup = AutoBackup.shared
    @State private var files: [BackupFile]?
    @State private var loadError: String?

    var body: some View {
        List {
            if tier == .cloud { cloudControls }
            Section {
                if let files {
                    ForEach(files) { file in
                        NavigationLink { BackupDetailView(tier: tier, file: file) } label: { BackupRow(tier: tier, file: file) }
                    }
                    if files.isEmpty {
                        Text("No backups yet").foregroundStyle(.secondary)
                    }
                } else if let loadError {
                    Text(loadError).foregroundStyle(.secondary)
                } else {
                    ProgressView().frame(maxWidth: .infinity)
                }
            } header: {
                Text(files.map { "\($0.count) \($0.count == 1 ? "backup" : "backups")" } ?? "Backups")
            } footer: {
                Text("\(tier.path). Saved within an hour of a change, each as its own file. Keeps everything from the last 2 days, the newest of each day for 2 weeks and of each month for a year, and always the newest 3.")
            }
            .listRowBackground(Theme.cardFill)
        }
        .scrollContentBackground(.hidden)
        .navigationTitle(tier.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private var cloudControls: some View {
        Section {
            Toggle(isOn: $backup.isEnabled) { Text("Back up to iCloud Drive") }
                .disabled(backup.status != .ready)
            Button {
                Task {
                    await backup.backUpNow()
                    await load()
                }
            } label: {
                HStack {
                    Label("Back up now", systemImage: "arrow.clockwise.icloud")
                    Spacer()
                    if backup.isBackingUp { ProgressView() }
                }
            }
            .disabled(!backup.isEnabled || backup.status != .ready || backup.isBackingUp || backup.isUpToDate)
        } footer: {
            if let error = backup.lastError {
                Text("Last backup failed: \(error)")
            } else if backup.isEnabled, backup.isUpToDate {
                Text("Up to date with this iPhone.")
            }
        }
        .listRowBackground(Theme.cardFill)
    }

    private func load() async {
        do {
            files = try await tier.files()
            loadError = nil
        } catch {
            files = nil
            loadError = error.localizedDescription
        }
    }
}

private struct BackupRow: View {
    let tier: BackupTier
    let file: BackupFile
    @State private var snapshot: BackupSnapshot?
    @State private var failed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(file.date?.formatted(date: .abbreviated, time: .shortened) ?? file.name).font(.cardTitle)
                Spacer()
                if let date = file.date {
                    Text(date, format: .relative(presentation: .named, unitsStyle: .abbreviated))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text([file.kind, file.size.map(Self.byteText)].compactMap { $0 }.joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(.secondary)
            if let snapshot {
                StatStrip(stats: snapshot.stats.filter { $0.count > 0 })
            } else if failed {
                Label(file.isDownloaded ? "Can't read this backup" : "Still in iCloud — pull to retry", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(file.isDownloaded ? Theme.Tone.bad : .secondary)
            } else {
                ProgressView().controlSize(.mini)
            }
        }
        .padding(.vertical, 2)
        .task(id: file) {
            snapshot = try? await tier.snapshot(of: file)
            failed = snapshot == nil
        }
    }

    static func byteText(_ bytes: Int) -> String {
        bytes.formatted(.byteCount(style: .file))
    }
}

private struct StatStrip: View {
    let stats: [BackupSnapshot.Stat]

    var body: some View {
        if stats.isEmpty {
            Text("Settings only").font(.caption).foregroundStyle(.secondary)
        } else {
            ViewThatFits(in: .horizontal) {
                strip(stats)
                strip(Array(stats.prefix(4)))
            }
        }
    }

    private func strip(_ stats: [BackupSnapshot.Stat]) -> some View {
        HStack(spacing: 10) {
            ForEach(stats) { stat in
                Label("\(stat.count)", systemImage: stat.symbol)
                    .accessibilityLabel(stat.text)
            }
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
        .fixedSize()
    }
}

/// Everything in one archive next to what's on the phone now, with restore.
private struct BackupDetailView: View {
    let tier: BackupTier
    let file: BackupFile
    @Environment(\.dismiss) private var dismiss
    @State private var snapshot: BackupSnapshot?
    @State private var loadError: String?
    @State private var confirming = false
    @State private var restoreError: String?
    @State private var current = BackupSnapshot.current()

    var body: some View {
        List {
            Section {
                LabeledContent("Saved", value: file.date?.formatted(date: .long, time: .shortened) ?? "—")
                LabeledContent("Kind", value: file.kind)
                if let size = file.size { LabeledContent("Size", value: BackupRow.byteText(size)) }
                if let version = snapshot?.appVersion, !version.isEmpty { LabeledContent("App version", value: version) }
                LabeledContent("File") { Text(file.name).font(.caption.monospaced()).textSelection(.enabled) }
            }
            .listRowBackground(Theme.cardFill)

            if let snapshot {
                Section {
                    ForEach(snapshot.stats) { stat in
                        LabeledContent {
                            HStack(spacing: 6) {
                                Text("\(stat.count)").monospacedDigit()
                                let now = nowCount(stat.key)
                                if now != stat.count {
                                    Text("now \(now)").font(.caption).foregroundStyle(.orange)
                                }
                            }
                        } label: {
                            Label(stat.label.capitalizedFirst, systemImage: stat.symbol)
                        }
                    }
                    LabeledContent {
                        Text("\(snapshot.settingsCount)").monospacedDigit()
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                } header: {
                    Text("Contents")
                } footer: {
                    Text("“now” is what this iPhone has where it differs.")
                }
                .listRowBackground(Theme.cardFill)

                Section {
                    Button("Restore this backup…", role: .destructive) { confirming = true }
                    ShareLink(item: file.url) { Label("Share file…", systemImage: "square.and.arrow.up") }
                } footer: {
                    Text("Restoring replaces everything backed up. What's here now is saved to This iPhone first.")
                }
                .listRowBackground(Theme.cardFill)
            } else if let loadError {
                Section { Text(loadError).foregroundStyle(.secondary) }.listRowBackground(Theme.cardFill)
            } else {
                Section { ProgressView().frame(maxWidth: .infinity) }.listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle(file.date?.formatted(date: .abbreviated, time: .shortened) ?? "Backup")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do {
                snapshot = try await tier.snapshot(of: file)
            } catch {
                loadError = file.isDownloaded || tier == .local ? error.localizedDescription : "Couldn't download it from iCloud yet. Try again shortly."
            }
        }
        .confirmationDialog("Replace your data with this backup?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Replace", role: .destructive, action: restore)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(snapshot?.summary ?? "")
        }
        .alert("Couldn't restore", isPresented: Binding(get: { restoreError != nil }, set: { if !$0 { restoreError = nil } })) {
            Button("OK") {}
        } message: {
            Text(restoreError ?? "")
        }
    }

    private func nowCount(_ key: String) -> Int {
        current.stats.first { $0.key == key }?.count ?? 0
    }

    private func restore() {
        guard let snapshot else { return }
        do {
            try BackupRestore.replace(with: snapshot, before: "restore")
            current = BackupSnapshot.current()
            dismiss()
        } catch {
            restoreError = error.localizedDescription
        }
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
