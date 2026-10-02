import Foundation
import SwiftData
import StillmoonCore

// CloudKit-compatible: every property has a default, no unique constraints (Plan 7 turns on sync).

@Model final class CheckInRecord {
    var id: UUID = UUID()
    var ownerID: String = ""
    var date: Date = Date.distantPast
    var restedness: Int = 3
    var tenseAtBedtime: Bool = false
    var wokeDuringNight: Bool = false
    var persistentDifficulty: Bool = false
    var note: String?

    init(ownerID: String, checkIn: CheckIn) {
        self.ownerID = ownerID
        update(from: checkIn)
    }

    func update(from c: CheckIn) {
        id = c.id
        date = c.date
        restedness = c.restedness
        tenseAtBedtime = c.tenseAtBedtime
        wokeDuringNight = c.wokeDuringNight
        persistentDifficulty = c.persistentDifficulty
        note = c.note
    }

    var value: CheckIn {
        CheckIn(id: id, date: date, restedness: restedness, tenseAtBedtime: tenseAtBedtime,
                wokeDuringNight: wokeDuringNight, persistentDifficulty: persistentDifficulty, note: note)
    }
}

@Model final class JournalEntryRecord {
    var id: UUID = UUID()
    var ownerID: String = ""
    var bedtime: Date = Date.distantPast
    var wakeTime: Date = Date.distantPast
    var note: String?

    init(ownerID: String, entry: JournalEntry) {
        self.ownerID = ownerID
        update(from: entry)
    }

    func update(from e: JournalEntry) {
        id = e.id
        bedtime = e.bedtime
        wakeTime = e.wakeTime
        note = e.note
    }

    var value: JournalEntry { JournalEntry(id: id, bedtime: bedtime, wakeTime: wakeTime, note: note) }
}

@Model final class CompletionRecord {
    var id: UUID = UUID()
    var ownerID: String = ""
    var exerciseID: String = ""
    var categoryRaw: String = ExerciseCategory.windDown.rawValue
    var completedAt: Date = Date.distantPast
    /// Set by the sync service in Plan 5.
    var syncedAt: Date?

    init(ownerID: String, completion: ExerciseCompletion) {
        self.ownerID = ownerID
        id = completion.id
        exerciseID = completion.exerciseID
        categoryRaw = completion.category.rawValue
        completedAt = completion.completedAt
    }

    var value: ExerciseCompletion {
        ExerciseCompletion(id: id, exerciseID: exerciseID,
                           category: ExerciseCategory(rawValue: categoryRaw) ?? .windDown,
                           completedAt: completedAt)
    }
}

@Model final class FeedbackRecord {
    var id: UUID = UUID()
    var ownerID: String = ""
    var itemID: String = ""
    var ratingRaw: String = FeedbackRating.helpful.rawValue
    var at: Date = Date.distantPast
    var syncedAt: Date?

    init(ownerID: String, feedback: RecommendationFeedback) {
        self.ownerID = ownerID
        id = feedback.id
        itemID = feedback.itemID
        ratingRaw = feedback.rating.rawValue
        at = feedback.at
    }

    var value: RecommendationFeedback {
        RecommendationFeedback(id: id, itemID: itemID, rating: FeedbackRating(rawValue: ratingRaw) ?? .helpful, at: at)
    }
}

@Model final class SavedItemRecord {
    var id: UUID = UUID()
    var ownerID: String = ""
    var itemID: String = ""
    /// Kept as a flag (not deleted) so last-write-wins sync in Plan 5 can carry "unsaved".
    var isSaved: Bool = false
    var updatedAt: Date = Date.distantPast

    init(ownerID: String, itemID: String, isSaved: Bool, updatedAt: Date) {
        self.ownerID = ownerID
        self.itemID = itemID
        self.isSaved = isSaved
        self.updatedAt = updatedAt
    }
}

@Model final class SoundSessionRecord {
    var id: UUID = UUID()
    var ownerID: String = ""
    var startedAt: Date = Date.distantPast
    var endedAt: Date?
    var interruptions: Int = 0

    init(ownerID: String, startedAt: Date) {
        self.ownerID = ownerID
        self.startedAt = startedAt
    }
}

@Model final class SoundEventRecord {
    var id: UUID = UUID()
    var ownerID: String = ""
    var sessionID: UUID = UUID()
    var labelRaw: String = SoundLabel.snoringLike.rawValue
    var at: Date = Date.distantPast
    var confidence: Double = 0
    var correctionRaw: String = SoundCorrection.none.rawValue

    init(ownerID: String, sessionID: UUID, event: SoundEvent) {
        self.ownerID = ownerID
        self.sessionID = sessionID
        id = event.id
        labelRaw = event.label.rawValue
        at = event.at
        confidence = event.confidence
        correctionRaw = event.correction.rawValue
    }

    /// Nil when the stored label is unknown (never invents a label).
    var value: SoundEvent? {
        guard let label = SoundLabel(rawValue: labelRaw) else { return nil }
        return SoundEvent(id: id, label: label, at: at, confidence: confidence,
                   correction: SoundCorrection(rawValue: correctionRaw) ?? .none)
    }
}
