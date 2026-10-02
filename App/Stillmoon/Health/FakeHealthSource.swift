import Foundation
import StillmoonCore

/// In-memory Health for unit tests and for UI tests launched with `-fake-health`.
final class FakeHealthSource: HealthDataSource {
    var isAvailable = true
    var samples: [SleepSample]
    var failReads = false
    private(set) var authorizationRequested = false
    private(set) var mindfulSessions: [DateInterval] = []

    init(samples: [SleepSample] = []) {
        self.samples = samples
    }

    func requestAuthorization() async throws {
        guard isAvailable else { throw HealthError.unavailable }
        authorizationRequested = true
    }

    func sleepSamples(from start: Date, to end: Date) async throws -> [SleepSample] {
        if failReads || !isAvailable { throw HealthError.unavailable }
        return samples.filter { $0.end > start && $0.start < end }
    }

    func saveMindfulSession(start: Date, end: Date) async throws {
        guard isAvailable else { throw HealthError.unavailable }
        mindfulSessions.append(DateInterval(start: start, end: end))
    }

    /// A staged night: 23:00 the evening before `morning` to 06:30 on it (7 h 20 m asleep).
    static func sampleNight(endingOn morning: Date, calendar: Calendar, source: String = "Apple Watch") -> [SleepSample] {
        let day = calendar.startOfDay(for: morning)
        let evening = calendar.date(byAdding: .day, value: -1, to: day)!
        func at(_ base: Date, _ h: Int, _ m: Int = 0) -> Date {
            calendar.date(bySettingHour: h, minute: m, second: 0, of: base)!
        }
        return [
            SleepSample(stage: .core, start: at(evening, 23), end: at(day, 1), sourceName: source),
            SleepSample(stage: .deep, start: at(day, 1), end: at(day, 2), sourceName: source),
            SleepSample(stage: .awake, start: at(day, 2), end: at(day, 2, 10), sourceName: source),
            SleepSample(stage: .rem, start: at(day, 2, 10), end: at(day, 3), sourceName: source),
            SleepSample(stage: .core, start: at(day, 3), end: at(day, 6, 30), sourceName: source),
        ]
    }
}
