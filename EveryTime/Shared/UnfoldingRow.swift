import SwiftUI

/// Form row whose picker unfolds beneath it; `open` keeps one open at a time.
struct UnfoldingRow<ID: Hashable, Title: View, Value: View, Control: View>: View {
    let id: ID
    @Binding var open: ID?
    @ViewBuilder var label: Title
    @ViewBuilder var value: Value
    @ViewBuilder var picker: Control

    private var isOpen: Bool { open == id }

    var body: some View {
        Group {
            Button {
                withAnimation(.snappy) { open = isOpen ? nil : id }
            } label: {
                LabeledContent {
                    HStack(spacing: 8) {
                        value.foregroundStyle(isOpen ? Color.accentColor : .primary)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(isOpen ? 90 : 0))
                    }
                } label: {
                    label
                }
                .contentShape(Rectangle())
            }
            .tint(.primary)
            if isOpen { picker }
        }
    }
}

extension Binding where Value == Int {
    /// Minutes after midnight as a time-of-day `Date` for pickers.
    var timeOfDay: Binding<Date> {
        Binding<Date> {
            Calendar.current.date(bySettingHour: wrappedValue / 60, minute: wrappedValue % 60, second: 0, of: .now) ?? .now
        } set: {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: $0)
            wrappedValue = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        }
    }
}

extension Int {
    /// Minutes after midnight → "11:00 PM".
    var timeOfDayText: String {
        let date = Calendar.current.date(bySettingHour: self / 60, minute: self % 60, second: 0, of: .now) ?? .now
        return date.formatted(.dateTime.hour().minute())
    }
}
