import SwiftUI

/// Columns (order, names, WIP limits) and the milestone calendar for one board.
struct BoardSettingsSheet: View {
    let original: BoardConfig
    let cards: [BoardCard]
    @State private var config: BoardConfig
    @State private var calendars: [BoardStore.ListInfo] = []
    @State private var renames: [(old: String, new: String)] = []
    @State private var renameCount = 0
    @State private var confirmingRename = false
    @State private var addingMilestone = false
    @State private var saving = false
    @State private var error: String?
    @FocusState private var focused: UUID?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    init(config: BoardConfig, cards: [BoardCard]) {
        original = config
        self.cards = cards
        _config = State(initialValue: config)
    }

    private var store: BoardStore { .shared }

    private var names: [String] { config.columns.map { $0.name.trimmingCharacters(in: .whitespaces) } }

    private var problem: String? {
        if names.contains(where: \.isEmpty) { return "Every column needs a name." }
        if names.contains(where: { $0.contains("·") }) { return "Column names can't contain “·”." }
        if names.contains(where: { $0.caseInsensitiveCompare(BoardConfig.doneName) == .orderedSame }) {
            return "“\(BoardConfig.doneName)” is always the last column."
        }
        if Set(names.map { $0.lowercased() }).count != names.count { return "Column names must be different." }
        return nil
    }

    var body: some View {
        List {
            Section {
                ForEach($config.columns) { $column in
                    HStack(spacing: Theme.spacing) {
                        Image(systemName: "line.3.horizontal").foregroundStyle(.tertiary)
                        TextField("Name", text: $column.name)
                            .focused($focused, equals: column.id)
                            .submitLabel(.done)
                        Text(column.wipLimit.map { "WIP \($0)" } ?? "WIP –")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .fixedSize()
                        Stepper("WIP limit", value: wip($column), in: 0...99)
                            .labelsHidden()
                    }
                }
                .onMove { config.columns.move(fromOffsets: $0, toOffset: $1) }
                .onDelete { config.columns.remove(atOffsets: $0) }
                .deleteDisabled(config.columns.count <= 1)
                HStack {
                    Text(BoardConfig.doneName)
                    Spacer()
                    Text("Always last, completes the reminder").font(.footnote).foregroundStyle(.secondary)
                }
                .padding(.leading, 30)
                Button {
                    let column = BoardColumn("")
                    config.columns.append(column)
                    focused = column.id
                } label: {
                    Label("Add column", systemImage: "plus")
                }
            } header: {
                Text("Columns")
            } footer: {
                if let problem {
                    Text(problem).foregroundStyle(Theme.Tone.warn)
                } else {
                    Text("Hold and drag to reorder, swipe to delete. Cards in a deleted column move to the first one.")
                }
            }
            .listRowBackground(Theme.cardFill)

            Section {
                milestones
            } header: {
                Text("Milestones")
            } footer: {
                Text("Milestones are all-day events in this calendar; they show on the Roadmap.")
            }
            .listRowBackground(Theme.cardFill)
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Board settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done", action: finish).fontWeight(.semibold).disabled(problem != nil || saving)
            }
        }
        .task(id: store.revision) { calendars = store.eventCalendars() }
        .sheet(isPresented: $addingMilestone) {
            if let calendarID = config.milestoneCalendarID {
                NavigationStack { MilestoneSheet(calendarID: calendarID) }
                    .presentationDetents([.medium])
            }
        }
        .alert("Rename on \(renameCount) \(renameCount == 1 ? "card" : "cards")?", isPresented: $confirmingRename) {
            Button("Rename") { Task { await applyRenames() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Their column is written in each reminder's notes.")
        }
        .alert("Couldn't save", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(error ?? "")
        }
    }

    @ViewBuilder
    private var milestones: some View {
        switch store.eventAccess {
        case .granted:
            Picker("Calendar", selection: $config.milestoneCalendarID) {
                Text("None").tag(String?.none)
                ForEach(calendars) { Text($0.title).tag(Optional($0.id)) }
            }
            .pickerStyle(.menu)
            if config.milestoneCalendarID != nil {
                Button { addingMilestone = true } label: { Label("Add milestone…", systemImage: "plus") }
            }
        case .unknown:
            Button { Task { await store.requestEventAccess() } } label: {
                Label("Allow Calendar access", systemImage: "calendar")
            }
        case .denied:
            Label("Calendar access is off", systemImage: "exclamationmark.triangle").foregroundStyle(.secondary)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
        }
    }

    private func wip(_ column: Binding<BoardColumn>) -> Binding<Int> {
        Binding(get: { column.wrappedValue.wipLimit ?? 0 },
                set: { column.wrappedValue.wipLimit = $0 > 0 ? $0 : nil })
    }

    private func finish() {
        for index in config.columns.indices {
            config.columns[index].name = names[index]
        }
        renames = config.columns.compactMap { column in
            guard let old = original.columns.first(where: { $0.id == column.id }), old.name != column.name else { return nil }
            return (old.name, column.name)
        }
        renameCount = cards.filter { card in
            !card.isCompleted && renames.contains { card.column?.caseInsensitiveCompare($0.old) == .orderedSame }
        }.count
        if renameCount > 0 {
            confirmingRename = true
        } else {
            store.save(config)
            dismiss()
        }
    }

    private func applyRenames() async {
        saving = true
        defer { saving = false }
        do {
            for rename in renames {
                try await store.renameColumn(in: config.listID, from: rename.old, to: rename.new)
            }
            store.save(config)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// Title + date → an all-day event in the board's milestone calendar.
private struct MilestoneSheet: View {
    let calendarID: String
    @State private var title = ""
    @State private var date = Date.now
    @State private var error: String?
    @FocusState private var titleFocused: Bool
    @Environment(\.dismiss) private var dismiss

    private var trimmed: String { title.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        Form {
            Section {
                TextField("Title", text: $title, prompt: Text("e.g. v1 release"))
                    .font(.cardTitle)
                    .focused($titleFocused)
                DatePicker("Date", selection: $date, displayedComponents: .date)
            }
            .listRowBackground(Theme.cardFill)
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("New milestone")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add", action: add).disabled(trimmed.isEmpty)
            }
        }
        .alert("Couldn't add", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(error ?? "")
        }
        .onAppear { titleFocused = true }
    }

    private func add() {
        do {
            try BoardStore.shared.addMilestone(trimmed, on: date, calendarID: calendarID)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
