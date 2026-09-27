import SwiftUI

struct BoardsListView: View {
    private let store = BoardStore.shared
    @State private var summaries: [String: BoardSummary] = [:]
    @State private var isLoaded = false
    @State private var isAdding = false
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        content
            .navigationTitle("Boards")
            .bottomBar { bottomAction }
            .sheet(isPresented: $isAdding) {
                NavigationStack { NewBoardSheet() }
                    .presentationDetents([.medium, .large])
            }
            .task(id: store.revision) { await load() }
            .onAppear { store.refresh() }
            .onChange(of: scenePhase) { _, phase in if phase == .active { store.refresh() } }
    }

    @ViewBuilder
    private var content: some View {
        switch store.access {
        case .unknown:
            ContentUnavailableView(
                "Boards live in Reminders",
                systemImage: "checklist",
                description: Text("Each board is a Reminders list; cards are reminders. Nothing leaves your iPhone.")
            )
        case .denied:
            ContentUnavailableView {
                Label("Reminders access is off", systemImage: "exclamationmark.triangle")
            } description: {
                Text("Settings → Privacy & Security → Reminders → Every Time")
            } actions: {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .buttonStyle(.soft)
            }
        case .granted:
            if !isLoaded {
                ProgressView()
            } else if store.configs.isEmpty {
                ContentUnavailableView(
                    "No boards yet",
                    systemImage: "rectangle.split.3x1",
                    description: Text("Turn a Reminders list into one.")
                )
            } else {
                boards
            }
        }
    }

    private var boards: some View {
        List {
            ForEach(store.configs) { config in
                BoardRow(summary: summaries[config.listID])
                    .background {
                        NavigationLink { BoardView(listID: config.listID) } label: { EmptyView() }.opacity(0)
                    }
                    .eventRow(vertical: 4)
                    .swipeActions {
                        Button("Remove board", role: .destructive) { store.removeBoard(config.listID) }
                    }
            }
            .onMove { store.moveBoards(from: $0, to: $1) }
            Text("Swipe to remove a board here. The Reminders list and its reminders stay.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .eventRow(vertical: 8)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private var bottomAction: some View {
        switch store.access {
        case .unknown:
            Button("Allow Reminders") { Task { await store.requestAccess() } }
                .buttonStyle(.primary)
        case .denied:
            EmptyView()
        case .granted:
            Button { isAdding = true } label: { Label("New board", systemImage: "plus") }
                .buttonStyle(.primary)
        }
    }

    private func load() async {
        guard store.access == .granted else { return }
        var result: [String: BoardSummary] = [:]
        for config in store.configs {
            guard let list = store.list(config.listID) else {
                result[config.listID] = .gone
                continue
            }
            let cards = await store.cards(in: config.listID)
            result[config.listID] = BoardSummary(list: list, config: config, groups: store.grouped(cards, by: config))
        }
        summaries = result
        isLoaded = true
    }
}

private struct BoardSummary {
    var title = ""
    var color = Color.secondary
    var open = 0
    var progress = 0.0
    var overdue = 0
    var inProgress = 0
    var isGone = false

    static let gone = BoardSummary(isGone: true)
}

extension BoardSummary {
    init(list: BoardStore.ListInfo, config: BoardConfig, groups: [(column: BoardColumn?, cards: [BoardCard])]) {
        let openCards = groups.filter { $0.column != nil }.flatMap(\.cards)
        let done = groups.last { $0.column == nil }?.cards.count ?? 0
        let now = Date.now
        self.init(
            title: list.title,
            color: list.color,
            open: openCards.count,
            progress: openCards.count + done == 0 ? 0 : Double(done) / Double(openCards.count + done),
            overdue: openCards.filter { $0.isOverdue(now: now) }.count,
            inProgress: groups.dropFirst().filter { $0.column != nil }.reduce(0) { $0 + $1.cards.count }
        )
    }
}

private struct BoardRow: View {
    let summary: BoardSummary?

    var body: some View {
        Card(padding: 14) {
            if let summary, summary.isGone {
                HStack(spacing: Theme.spacing) {
                    Label("This Reminders list is gone", systemImage: "exclamationmark.triangle")
                        .font(.cardTitle)
                        .foregroundStyle(Theme.Tone.warn)
                    Spacer(minLength: 0)
                    chevron
                }
            } else if let summary {
                HStack(spacing: 10) {
                    Circle().fill(summary.color).frame(width: 10, height: 10)
                    Text(summary.title).font(.cardTitle).lineLimit(1)
                    Spacer(minLength: 0)
                    Text("\(summary.open)")
                        .font(.label)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                    chevron
                }
                HStack(spacing: 10) {
                    ProgressView(value: summary.progress)
                        .tint(summary.color)
                        .frame(maxWidth: 120)
                    Text(summary.progress, format: .percent.precision(.fractionLength(0)))
                        .foregroundStyle(.secondary)
                    Text("·").foregroundStyle(.tertiary)
                    if summary.overdue > 0 {
                        Text("\(summary.overdue) overdue").foregroundStyle(Theme.Tone.bad)
                    } else {
                        Text("\(summary.inProgress) in progress").foregroundStyle(.secondary)
                    }
                }
                .font(.subheadline)
                .monospacedDigit()
                .lineLimit(1)
                .padding(.leading, 20)
            } else {
                HStack {
                    ProgressView()
                    Spacer(minLength: 0)
                    chevron
                }
            }
        }
        .animation(.snappy, value: summary?.open)
        .contentShape(Rectangle())
    }

    private var chevron: some View {
        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
    }
}

#Preview {
    NavigationStack { BoardsListView() }
}
