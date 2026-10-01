import Foundation

/// The span searched for one night's sleep: 18:00 the previous day to 12:00 on the morning day.
public struct NightWindow: Sendable, Equatable {
    public let start: Date
    public let end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }

    public static func forMorning(of day: Date, calendar: Calendar) -> NightWindow {
        let morning = calendar.startOfDay(for: day)
        let previous = calendar.date(byAdding: .day, value: -1, to: morning)!
        let start = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: previous)!
        let end = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: morning)!
        return NightWindow(start: start, end: end)
    }

    /// Identifies which night a moment belongs to: the calendar day the night started on.
    /// Anything before noon belongs to the previous day's night.
    public static func nightKey(for date: Date, calendar: Calendar) -> Date {
        calendar.startOfDay(for: calendar.date(byAdding: .hour, value: -12, to: date)!)
    }
}
