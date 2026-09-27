import SwiftUI

/// One board: [ Board | Roadmap | Insights ].
struct BoardView: View {
    let listID: String

    private enum Mode: String, CaseIterable, Identifiable {
        case board = "Board", roadmap = "Roadmap", insights = "Insights"
        var id: String { rawValue }
    }

    private enum Sheet: Identifiable {
        case new(BoardColumn?)
        case edit(BoardCard)
        case settings

        var id: String {
            switch self {
            case .new: "new"
            case .edit(let card): card.id
            case .settings: "settings"
            }
        }
    }

    @State private var mode = Mode.board
    @State private var cards: [BoardCard] = []
    @State private var lanes: [BoardLane] = []
    @State private var list: BoardStore.ListInfo?
    @State private var loaded = false
    @State private var sheet: Sheet?
    @State private var deleting: BoardCard?
    @State private var error: String?
    @State private var moves = 0
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private var store: BoardStore { .shared }
    private var config: BoardConfig? { store.config(for: listID) }

    var body: some View {
        content
            .navigationTitle(list?.title ?? "Board")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if config != nil, list != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button { sheet = .settings } label: { Image(systemName: "ellipsis.circle") }
                            .accessibilityLabel("Board settings")
                    }
                }
            }
            .task(id: store.revision) { await load() }
            .sheet(item: $sheet, onDismiss: reload) { sheet in
                if let config {
                    NavigationStack {
                        switch sheet {
                        case .new(let column):
                            CardSheet(card: .blank, column: column ?? config.columns.first, config: config, listID: listID, isNew: true)
                        case .edit(let card):
                            CardSheet(card: card, column: config.column(of: card), config: config, listID: listID, isNew: false)
                        case .settings:
                            BoardSettingsSheet(config: config, cards: cards)
                        }
                    }
                }
            }
            .alert("Delete “\(deleting?.title ?? "")”?",
                   isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                   presenting: deleting) { card in
                if !card.isCompleted {
                    Button("Move to Done") { move(card, to: nil) }
                }
                Button("Delete", role: .destructive) { write { try store.delete(card) } }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("It's removed from Reminders on all your devices.")
            }
            .alert("Couldn't save", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(error ?? "")
            }
            .sensoryFeedback(.success, trigger: moves)
    }

    @ViewBuilder
    private var content: some View {
        if store.access != .granted {
            ContentUnavailableView {
                Label("Reminders access is off", systemImage: "exclamationmark.triangle")
            } actions: {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .buttonStyle(.soft)
            }
        } else if !loaded {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let config, list != nil {
            VStack(spacing: Theme.spacing) {
                Picker("View", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .screen()
                switch mode {
                case .board:
                    board
                case .roadmap:
                    ScrollView {
                        BoardRoadmapView(config: config, cards: cards) { sheet = .edit($0) }
                            .screen()
                            .padding(.bottom, Theme.padding)
                    }
                case .insights:
                    ScrollView {
                        BoardInsightsView(config: config, cards: cards)
                            .screen()
                            .padding(.bottom, Theme.padding)
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        } else {
            ContentUnavailableView {
                Label("This Reminders list is gone", systemImage: "exclamationmark.triangle")
            } actions: {
                Button("Remove board") {
                    store.removeBoard(listID)
                    dismiss()
                }
                .buttonStyle(.soft)
            }
        }
    }

    @ViewBuilder
    private var board: some View {
        if cards.isEmpty {
            ContentUnavailableView {
                Label("No cards yet", systemImage: "rectangle.split.3x1")
            } description: {
                Text("Cards are reminders in this list.")
            } actions: {
                Button { sheet = .new(nil) } label: { Label("Add card", systemImage: "plus") }
                    .buttonStyle(.primary)
                    .frame(maxWidth: 240)
            }
        } else {
            BoardColumnsView(lanes: lanes,
                             onOpen: { sheet = .edit($0) },
                             onAdd: { sheet = .new($0) },
                             onMove: move,
                             onDelete: { deleting = $0 })
        }
    }

    private func load() async {
        guard store.access == .granted else { return }
        list = store.list(listID)
        if let config, list != nil {
            cards = await store.cards(in: listID)
            lanes = store.grouped(cards, by: config).map { BoardLane(column: $0.column, cards: $0.cards) }
        }
        loaded = true
    }

    private func reload() { Task { await load() } }

    private func move(_ card: BoardCard, to column: BoardColumn?) {
        write { try store.move(card, to: column) }
        moves += 1
    }

    private func write(_ change: () throws -> Void) {
        do {
            try change()
        } catch {
            self.error = error.localizedDescription
        }
        reload()
    }
}
