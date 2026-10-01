import Foundation

public enum SleepStage: String, Codable, Sendable, CaseIterable {
    case inBed, awake, core, deep, rem, asleepUnspecified

    /// Stages that count as sleep time.
    public var isAsleep: Bool {
        switch self {
        case .core, .deep, .rem, .asleepUnspecified: true
        case .inBed, .awake: false
        }
    }

    /// Stages only a stage-tracking wearable records.
    public var isDetailed: Bool {
        switch self {
        case .core, .deep, .rem: true
        case .inBed, .awake, .asleepUnspecified: false
        }
    }
}

public struct SleepSample: Codable, Sendable, Hashable {
    public var stage: SleepStage
    public var start: Date
    public var end: Date
    /// HealthKit source name, shown to the user as "Recorded by".
    public var sourceName: String

    public init(stage: SleepStage, start: Date, end: Date, sourceName: String) {
        self.stage = stage
        self.start = start
        self.end = end
        self.sourceName = sourceName
    }
}

public struct CheckIn: Codable, Sendable, Hashable {
    public var id: UUID
    public var date: Date
    /// 1 (not rested) ... 5 (very rested)
    public var restedness: Int
    public var tenseAtBedtime: Bool
    public var wokeDuringNight: Bool
    /// "Trouble sleeping most nights for 3+ weeks"
    public var persistentDifficulty: Bool
    public var note: String?

    public init(id: UUID = UUID(), date: Date, restedness: Int, tenseAtBedtime: Bool = false,
                wokeDuringNight: Bool = false, persistentDifficulty: Bool = false, note: String? = nil) {
        self.id = id
        self.date = date
        self.restedness = restedness
        self.tenseAtBedtime = tenseAtBedtime
        self.wokeDuringNight = wokeDuringNight
        self.persistentDifficulty = persistentDifficulty
        self.note = note
    }
}

public enum SoundLabel: String, Codable, Sendable, CaseIterable {
    case snoringLike, speechLike, coughLike
}

public enum SoundCorrection: String, Codable, Sendable {
    /// Not reviewed by the user.
    case none
    case incorrect
    case someoneElse
    case wasMe
}

public struct SoundEvent: Codable, Sendable, Hashable {
    public var id: UUID
    public var label: SoundLabel
    public var at: Date
    public var confidence: Double
    public var correction: SoundCorrection

    public init(id: UUID = UUID(), label: SoundLabel, at: Date, confidence: Double, correction: SoundCorrection = .none) {
        self.id = id
        self.label = label
        self.at = at
        self.confidence = confidence
        self.correction = correction
    }
}

public enum ExerciseCategory: String, Codable, Sendable, CaseIterable {
    case windDown, awakeAtNight, morningReset, learn
}

public struct ExerciseCompletion: Codable, Sendable, Hashable {
    /// Client-generated; the sync key.
    public var id: UUID
    public var exerciseID: String
    public var category: ExerciseCategory
    public var completedAt: Date

    public init(id: UUID = UUID(), exerciseID: String, category: ExerciseCategory, completedAt: Date) {
        self.id = id
        self.exerciseID = exerciseID
        self.category = category
        self.completedAt = completedAt
    }
}

public enum Goal: String, Codable, Sendable, CaseIterable {
    case unwind, understandSleep, nightWaking, consistency
}
