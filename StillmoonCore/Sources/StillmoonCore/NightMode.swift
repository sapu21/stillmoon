import Foundation

public struct ClockTime: Codable, Sendable, Hashable {
    public var hour: Int
    public var minute: Int

    public init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    public init(of date: Date, calendar: Calendar) {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        self.init(hour: c.hour!, minute: c.minute!)
    }

    public var minutesOfDay: Int { hour * 60 + minute }

    /// Minutes after 18:00, so evening and after-midnight times sort on one line.
    public var minutesSinceSixPM: Int { (minutesOfDay - 18 * 60 + 1440) % 1440 }
}

public enum NightModeResolver {
    public static let defaultBedtime = ClockTime(hour: 22, minute: 0)
    public static let defaultWake = ClockTime(hour: 7, minute: 0)
    static let leadMinutes = 60

    public static func isNight(at now: Date, calendar: Calendar, bedtime: ClockTime?, wake: ClockTime?,
                               sessionActive: Bool, manualOverride: Bool?) -> Bool {
        if let manualOverride { return manualOverride }
        if sessionActive { return true }

        let start = ((bedtime ?? defaultBedtime).minutesOfDay - leadMinutes + 1440) % 1440
        let end = (wake ?? defaultWake).minutesOfDay
        let m = ClockTime(of: now, calendar: calendar).minutesOfDay
        if start == end { return false }
        return start < end ? (m >= start && m < end) : (m >= start || m < end)
    }
}
