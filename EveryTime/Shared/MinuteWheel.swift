import SwiftUI

/// A time (or date and time) wheel that moves in 10-minute steps; SwiftUI's DatePicker has no minute interval.
struct MinuteWheel: UIViewRepresentable {
    @Binding var date: Date
    var showsDate = false
    var timeZone: TimeZone = .current
    var minuteInterval = 10

    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.preferredDatePickerStyle = .wheels
        picker.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .valueChanged)
        picker.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return picker
    }

    func updateUIView(_ picker: UIDatePicker, context: Context) {
        context.coordinator.date = $date
        picker.datePickerMode = showsDate ? .dateAndTime : .time
        picker.minuteInterval = minuteInterval
        picker.timeZone = timeZone
        if abs(picker.date.timeIntervalSince(date)) >= 1 { picker.date = date }
    }

    func makeCoordinator() -> Coordinator { Coordinator(date: $date) }

    final class Coordinator: NSObject {
        var date: Binding<Date>
        init(date: Binding<Date>) { self.date = date }
        @objc func changed(_ picker: UIDatePicker) { date.wrappedValue = picker.date }
    }
}
