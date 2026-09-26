import SwiftUI
import UIKit

/// Copies to the pasteboard; inside `.copyToast()` it also shows "Copied".
struct CopyAction {
    var onCopy: (String) -> Void = { UIPasteboard.general.string = $0 }
    func callAsFunction(_ value: String) { onCopy(value) }
}

extension EnvironmentValues {
    @Entry var copy = CopyAction()
}

struct CopyButton<Label: View>: View {
    let value: () -> String
    @ViewBuilder let label: Label
    @Environment(\.copy) private var copy

    var body: some View {
        Button { copy(value()) } label: { label }
            .buttonStyle(.plain)
            .accessibilityHint("Copies to clipboard")
    }
}

/// Label over value, copy icon trailing; sits inside a `Card`.
struct CopyableRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.label)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(.body, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: value)
            }
            Spacer(minLength: 0)
            CopyButton(value: { value }) {
                Image(systemName: "doc.on.doc")
                    .foregroundStyle(.tint)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Copy \(title)")
        }
    }
}

private struct CopyToast: ViewModifier {
    @State private var copies = 0
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .environment(\.copy, CopyAction { value in
                UIPasteboard.general.string = value
                copies += 1
            })
            .overlay(alignment: .bottom) {
                if isVisible {
                    Label("Copied", systemImage: "checkmark")
                        .font(.label)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.bottom, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .task(id: copies) {
                guard copies > 0 else { return }
                withAnimation(.snappy) { isVisible = true }
                try? await Task.sleep(for: .seconds(1.2))
                guard !Task.isCancelled else { return }
                withAnimation(.snappy) { isVisible = false }
            }
            .sensoryFeedback(.success, trigger: copies)
    }
}

extension View {
    /// Hosts copy actions below it and shows a brief "Copied" toast.
    func copyToast() -> some View {
        modifier(CopyToast())
    }
}
