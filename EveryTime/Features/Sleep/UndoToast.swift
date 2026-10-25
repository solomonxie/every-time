import SwiftUI

/// A short message at the bottom, with Undo when there's something to undo; gone after 4 s.
struct UndoToast: Equatable {
    let text: String
    let undo: (() -> Void)?
    let id = UUID()

    static func == (a: UndoToast, b: UndoToast) -> Bool { a.id == b.id }
}

extension View {
    func undoToast(_ toast: Binding<UndoToast?>) -> some View {
        overlay(alignment: .bottom) { UndoToastView(toast: toast) }
    }
}

private struct UndoToastView: View {
    @Binding var toast: UndoToast?

    var body: some View {
        if let toast {
            HStack(spacing: 14) {
                Text(toast.text).font(.label)
                if let undo = toast.undo {
                    Button("Undo") { undo(); withAnimation(.snappy) { self.toast = nil } }
                        .font(.label.weight(.bold))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
            .padding(.bottom, 80)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .task(id: toast) {
                try? await Task.sleep(for: .seconds(4))
                guard !Task.isCancelled else { return }
                withAnimation(.snappy) { self.toast = nil }
            }
        }
    }
}
