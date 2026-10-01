import Foundation

public struct NightExport: Codable, Sendable, Equatable {
    public var nightOf: Date
    public var sleepStart: Date
    public var sleepEnd: Date
    public var asleepMinutes: Int
    public var primarySource: String
    public var samples: [SleepSample]

    public init(nightOf: Date, sleepStart: Date, sleepEnd: Date, asleepMinutes: Int,
                primarySource: String, samples: [SleepSample]) {
        self.nightOf = nightOf
        self.sleepStart = sleepStart
        self.sleepEnd = sleepEnd
        self.asleepMinutes = asleepMinutes
        self.primarySource = primarySource
        self.samples = samples
    }
}

/// Everything one account has, local and server-side, for the user's export.
public struct ExportBundle: Codable, Sendable, Equatable {
    public var exportedAt: Date
    public var nights: [NightExport]
    public var checkIns: [CheckIn]
    public var soundEvents: [SoundEvent]
    public var completions: [ExerciseCompletion]
    public var feedback: [RecommendationFeedback]

    public init(exportedAt: Date, nights: [NightExport], checkIns: [CheckIn], soundEvents: [SoundEvent],
                completions: [ExerciseCompletion], feedback: [RecommendationFeedback]) {
        self.exportedAt = exportedAt
        self.nights = nights
        self.checkIns = checkIns
        self.soundEvents = soundEvents
        self.completions = completions
        self.feedback = feedback
    }
}

public enum ExportWriter {
    public static func json(_ bundle: ExportBundle) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(bundle)
    }

    public static func decode(_ data: Data) throws -> ExportBundle {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ExportBundle.self, from: data)
    }

    public static func nightsCSV(_ nights: [NightExport]) -> String {
        csv(header: ["night_of", "sleep_start", "sleep_end", "asleep_minutes", "source"],
            rows: nights.map { [iso($0.nightOf), iso($0.sleepStart), iso($0.sleepEnd), String($0.asleepMinutes), $0.primarySource] })
    }

    public static func checkInsCSV(_ checkIns: [CheckIn]) -> String {
        csv(header: ["date", "restedness", "tense_at_bedtime", "woke_during_night", "persistent_difficulty", "note"],
            rows: checkIns.map { [iso($0.date), String($0.restedness), String($0.tenseAtBedtime),
                                  String($0.wokeDuringNight), String($0.persistentDifficulty), $0.note ?? ""] })
    }

    public static func soundEventsCSV(_ events: [SoundEvent]) -> String {
        csv(header: ["time", "label", "confidence", "correction"],
            rows: events.map { [iso($0.at), $0.label.rawValue, String($0.confidence), $0.correction.rawValue] })
    }

    static func csv(header: [String], rows: [[String]]) -> String {
        ([header] + rows).map { $0.map(field).joined(separator: ",") + "\n" }.joined()
    }

    static func field(_ value: String) -> String {
        // Unicode scalars, not Characters: "\r\n" is one Character and would match neither "\r" nor "\n".
        let needsQuotes = value.unicodeScalars.contains { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }
        guard needsQuotes else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func iso(_ date: Date) -> String {
        date.formatted(.iso8601)
    }
}
