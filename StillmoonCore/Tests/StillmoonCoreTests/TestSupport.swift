import Foundation

/// Fixed calendar so tests never depend on the machine's time zone.
enum T {
    static let tz = TimeZone(identifier: "America/New_York")!

    static var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = tz
        c.firstWeekday = 1 // Sunday
        return c
    }

    static func d(_ y: Int, _ mo: Int, _ day: Int, _ h: Int = 0, _ mi: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: mo, day: day, hour: h, minute: mi))!
    }
}
