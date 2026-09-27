import SwiftUI

/// EventKit priority as the board shows it: none, low (9), medium (5), high (1).
enum CardPriority: Int, CaseIterable, Identifiable {
    case none = 0, low = 9, medium = 5, high = 1

    var id: Int { rawValue }

    init(_ priority: Int) {
        switch priority {
        case 1...4: self = .high
        case 5: self = .medium
        case 6...9: self = .low
        default: self = .none
        }
    }

    var title: String {
        switch self {
        case .none: "None"
        case .low: "!"
        case .medium: "!!"
        case .high: "!!!"
        }
    }
}

extension BoardCard {
    static var blank: BoardCard {
        BoardCard(id: "", title: "", notes: "", priority: 0, isCompleted: false)
    }
}

/// New or existing card: title, column, estimate, due date, priority, notes.
struct CardSheet: View {
    let listID: String
    let config: BoardConfig
    let isNew: Bool
    @State private var card: BoardCard
    @State private var columnID: UUID?
    @State private var confirmingDelete = false
    @State private var error: String?
    @FocusState private var titleFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    /// `column == nil` means Done.
    init(card: BoardCard, column: BoardColumn?, config: BoardConfig, listID: String, isNew: Bool) {
        _card = State(initialValue: card)
        _columnID = State(initialValue: column?.id)
        self.config = config
        self.listID = listID
        self.isNew = isNew
    }

    private var store: BoardStore { .shared }
    private var trimmedTitle: String { card.title.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var points: Binding<Int> {
        Binding(get: { card.points ?? 0 }, set: { card.points = $0 > 0 ? $0 : nil })
    }

    private var hasDue: Binding<Bool> {
        Binding(get: { card.due != nil }, set: { card.due = $0 ? Self.day(.now) : nil })
    }

    private var dueDate: Binding<Date> {
        Binding(get: { card.dueDate ?? .now }, set: { card.due = Self.day($0) })
    }

    private var priority: Binding<CardPriority> {
        Binding(get: { CardPriority(card.priority) }, set: { card.priority = $0.rawValue })
    }

    var body: some View {
        Form {
            Section {
                TextField("Title", text: $card.title, axis: .vertical)
                    .font(.cardTitle)
                    .lineLimit(1...4)
                    .focused($titleFocused)
            }
            .listRowBackground(Theme.cardFill)

            Section {
                Picker("Column", selection: $columnID) {
                    ForEach(config.columns) { Text($0.name).tag(Optional($0.id)) }
                    Text(BoardConfig.doneName).tag(UUID?.none)
                }
                .pickerStyle(.menu)
                Stepper(value: points, in: 0...99) {
                    HStack {
                        Text("Estimate")
                        Spacer()
                        Text(points.wrappedValue == 0 ? "None" : "\(points.wrappedValue) \(points.wrappedValue == 1 ? "pt" : "pts")")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                }
                Toggle("Due", isOn: hasDue.animation(.snappy))
                if card.due != nil {
                    DatePicker("Date", selection: dueDate, displayedComponents: .date)
                }
                Picker("Priority", selection: priority) {
                    ForEach(CardPriority.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            .listRowBackground(Theme.cardFill)

            Section("Notes") {
                TextField("Notes", text: $card.notes, axis: .vertical)
                    .lineLimit(3...12)
            }
            .listRowBackground(Theme.cardFill)

            if !isNew {
                Section {
                    if let url = card.remindersURL {
                        Button { openURL(url) } label: {
                            HStack {
                                Text("Open in Reminders")
                                Spacer()
                                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                            }
                        }
                    }
                    Button("Delete card…", role: .destructive) { confirmingDelete = true }
                }
                .listRowBackground(Theme.cardFill)
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle(isNew ? "New card" : "Card")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save).disabled(trimmedTitle.isEmpty)
            }
        }
        .alert("Delete “\(card.title)”?", isPresented: $confirmingDelete) {
            if !card.isCompleted {
                Button("Move to Done") { columnID = nil; save() }
            }
            Button("Delete", role: .destructive, action: delete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It's removed from Reminders on all your devices.")
        }
        .alert("Couldn't save", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(error ?? "")
        }
        .sensoryFeedback(.selection, trigger: columnID)
        .onAppear { if isNew { titleFocused = true } }
    }

    private func save() {
        card.title = trimmedTitle
        let column = config.columns.first { $0.id == columnID }
        do {
            if isNew {
                try store.create(card, in: listID, column: column)
            } else {
                try store.save(card, column: column)
            }
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func delete() {
        do {
            try store.delete(card)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private static func day(_ date: Date) -> DateComponents {
        Calendar.current.dateComponents([.year, .month, .day], from: date)
    }
}
