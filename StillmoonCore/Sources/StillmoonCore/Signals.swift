import Foundation

/// Structured signals for the "talk to a professional" messages. Journal text is never read.
public enum ReferralSignals {
    static let snoringNights = 5
    static let lookbackDays = 7

    public static func showsDifficultyCard(todayCheckIn: CheckIn?) -> Bool {
        todayCheckIn?.persistentDifficulty ?? false
    }

    public static func showsSnoringNote(events: [SoundEvent], now: Date, calendar: Calendar,
                                        alreadyShown: Bool) -> Bool {
        guard !alreadyShown else { return false }
        let since = calendar.date(byAdding: .day, value: -lookbackDays, to: now)!
        let nights = Set(events
            .filter { $0.label == .snoringLike && $0.correction == .wasMe && $0.at >= since && $0.at <= now }
            .map { NightWindow.nightKey(for: $0.at, calendar: calendar) })
        return nights.count >= snoringNights
    }
}

/// The internal launch gate for sound detection (PRD §6).
public enum SoundGate {
    public static let maxFalseRate = 0.2

    /// Share of reviewed events the user marked incorrect or someone else; nil if none reviewed.
    public static func falseRate(_ events: [SoundEvent]) -> Double? {
        let reviewed = events.filter { $0.correction != .none }
        guard !reviewed.isEmpty else { return nil }
        let wrong = reviewed.filter { $0.correction == .incorrect || $0.correction == .someoneElse }
        return Double(wrong.count) / Double(reviewed.count)
    }

    public static func passes(_ events: [SoundEvent]) -> Bool {
        guard let rate = falseRate(events) else { return false }
        return rate < maxFalseRate
    }
}
