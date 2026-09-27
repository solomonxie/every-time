import Foundation

/// No DST, so fixed-offset arithmetic in the app matches wall-clock time.
let shanghai = TimeZone(identifier: "Asia/Shanghai")!

func gregorian(_ timeZone: TimeZone = shanghai) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    return calendar
}

func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0, _ second: Int = 0,
          in timeZone: TimeZone = shanghai) -> Date {
    gregorian(timeZone).date(from: DateComponents(year: year, month: month, day: day,
                                                  hour: hour, minute: minute, second: second))!
}
