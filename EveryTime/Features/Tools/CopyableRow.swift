import SwiftUI
import UIKit

struct CopyButton<Label: View>: View {
    let value: () -> String
    @ViewBuilder let label: Label
    @State private var copied = false

    var body: some View {
        Button {
            UIPasteboard.general.string = value()
            copied = true
            Task {
                try? await Task.sleep(for: .seconds(1.2))
                copied = false
            }
        } label: {
            label
                .overlay(alignment: .trailing) {
                    if copied {
                        Text("Copied")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.tint, in: Capsule())
                            .foregroundStyle(.white)
                            .transition(.opacity)
                    }
                }
                .animation(.easeOut(duration: 0.15), value: copied)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: copied) { _, new in new }
        .accessibilityHint("Copies to clipboard")
    }
}

struct CopyableRow: View {
    let title: String
    let value: String

    var body: some View {
        CopyButton(value: { value }) {
            HStack {
                Text(title)
                Spacer()
                Text(value)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Image(systemName: "doc.on.doc")
                    .foregroundStyle(.tint)
            }
            .contentShape(Rectangle())
        }
    }
}
