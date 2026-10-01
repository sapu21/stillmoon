import Foundation

/// A night the user recorded by hand (FR-03). Always shown as user-entered, never as a measurement.
struct JournalEntry: Identifiable, Hashable {
    var id: UUID = UUID()
    var bedtime: Date
    var wakeTime: Date
    var note: String?

    var asleepMinutes: Int { Int(wakeTime.timeIntervalSince(bedtime) / 60) }

    /// nil when the entry can be saved, otherwise a message for the form.
    func validationMessage() -> String? {
        let hours = wakeTime.timeIntervalSince(bedtime) / 3600
        if hours <= 0 { return "Wake time needs to be after bedtime." }
        if hours > 16 { return "That's more than 16 hours. Check the dates." }
        return nil
    }

    /// Yesterday 23:00 to today 07:00, as a starting point for the form.
    static func defaultEntry(now: Date, calendar: Calendar) -> JournalEntry {
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        return JournalEntry(
            bedtime: calendar.date(bySettingHour: 23, minute: 0, second: 0, of: yesterday)!,
            wakeTime: calendar.date(bySettingHour: 7, minute: 0, second: 0, of: today)!
        )
    }
}
