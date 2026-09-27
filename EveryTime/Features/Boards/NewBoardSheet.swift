import SwiftUI

/// Turn an existing Reminders list into a board, or create a new list for one.
struct NewBoardSheet: View {
    private let store = BoardStore.shared
    @State private var lists: [BoardStore.ListInfo] = []
    @State private var counts: [String: Int] = [:]
    @State private var selectedID: String?
    @State private var newName = ""
    @State private var template = BoardConfig.Template.standard
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    private var trimmedName: String { newName.trimmingCharacters(in: .whitespaces) }
    private var canCreate: Bool { selectedID != nil || !trimmedName.isEmpty }

    var body: some View {
        Form {
            if !lists.isEmpty {
                Section("Use a Reminders list") {
                    ForEach(lists) { list in
                        Button { choose(list.id) } label: { listRow(list) }
                            .buttonStyle(.plain)
                    }
                }
                .listRowBackground(Theme.cardFill)
            }
            Section(lists.isEmpty ? "Create a list" : "Or create one") {
                TextField("New list name", text: $newName)
                    .submitLabel(.done)
                    .onChange(of: newName) { _, name in
                        if !name.isEmpty { selectedID = nil }
                    }
            }
            .listRowBackground(Theme.cardFill)
            Section {
                Picker("Columns", selection: $template) {
                    ForEach(BoardConfig.Template.allCases) { template in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(template.name)
                            Text(template.title).font(.footnote).foregroundStyle(.secondary)
                        }
                        .tag(template)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Columns")
            } footer: {
                Text("You can rename, add and reorder columns later.")
            }
            .listRowBackground(Theme.cardFill)
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("New board")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        }
        .bottomBar {
            Button("Create", action: create)
                .buttonStyle(.primary)
                .disabled(!canCreate)
                .opacity(canCreate ? 1 : 0.4)
        }
        .alert("Couldn't create the board", isPresented: Binding { error != nil } set: { if !$0 { error = nil } }) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(error ?? "")
        }
        .sensoryFeedback(.selection, trigger: selectedID)
        .task(id: store.revision) { await load() }
    }

    private func listRow(_ list: BoardStore.ListInfo) -> some View {
        HStack(spacing: Theme.spacing) {
            Image(systemName: selectedID == list.id ? "largecircle.fill.circle" : "circle")
                .foregroundStyle(selectedID == list.id ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
            Circle().fill(list.color).frame(width: 10, height: 10)
            Text(list.title).lineLimit(1)
            Spacer(minLength: 0)
            if let count = counts[list.id] {
                Text("\(count) \(count == 1 ? "item" : "items")")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }

    private func choose(_ id: String) {
        selectedID = id
        newName = ""
    }

    private func load() async {
        let used = Set(store.configs.map(\.listID))
        lists = store.lists().filter { $0.isWritable && !used.contains($0.id) }
        for list in lists where counts[list.id] == nil {
            counts[list.id] = await store.cards(in: list.id).filter { !$0.isCompleted }.count
        }
    }

    private func create() {
        do {
            let listID = try selectedID ?? store.createList(named: trimmedName).id
            store.save(BoardConfig(listID: listID, template: template))
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private extension BoardConfig.Template {
    var name: String {
        switch self {
        case .standard: "Standard"
        case .simple: "Simple"
        case .zenhub: "ZenHub"
        }
    }
}
