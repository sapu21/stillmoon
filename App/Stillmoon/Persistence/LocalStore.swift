import Foundation
import SwiftData
import StillmoonCore

enum StillmoonSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [CheckInRecord.self, JournalEntryRecord.self, CompletionRecord.self, FeedbackRecord.self, SavedItemRecord.self]
    }
}

enum StillmoonSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [CheckInRecord.self, JournalEntryRecord.self, CompletionRecord.self, FeedbackRecord.self,
         SavedItemRecord.self, SoundSessionRecord.self, SoundEventRecord.self]
    }
}

enum StillmoonMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [StillmoonSchemaV1.self, StillmoonSchemaV2.self] }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: StillmoonSchemaV1.self, toVersion: StillmoonSchemaV2.self)]
    }
}

enum StillmoonSchema {
    /// Two named stores so each can later sync somewhere different: health data (check-ins, journal, sound)
    /// is destined for the user's own iCloud (PRD section 9), account data (completions, feedback, saved items)
    /// for Supabase. Both stay local with `cloudKitDatabase: .none` until those plans land.
    /// `directory` is where on-disk stores live (nil = SwiftData default).
    static func makeContainer(inMemory: Bool, directory: URL? = nil) throws -> ModelContainer {
        let health = configuration("health", [CheckInRecord.self, JournalEntryRecord.self,
                                              SoundSessionRecord.self, SoundEventRecord.self],
                                   inMemory: inMemory, directory: directory)
        let account = configuration("account", [CompletionRecord.self, FeedbackRecord.self, SavedItemRecord.self],
                                    inMemory: inMemory, directory: directory)
        return try ModelContainer(for: Schema(versionedSchema: StillmoonSchemaV2.self),
                                  migrationPlan: StillmoonMigrationPlan.self,
                                  configurations: [health, account])
    }

    /// The Plan 3 (V1) on-disk layout, used only to prove the V1 to V2 migration.
    static func makeV1ContainerForTesting(directory: URL) throws -> ModelContainer {
        let health = configuration("health", [CheckInRecord.self, JournalEntryRecord.self],
                                   inMemory: false, directory: directory)
        let account = configuration("account", [CompletionRecord.self, FeedbackRecord.self, SavedItemRecord.self],
                                    inMemory: false, directory: directory)
        return try ModelContainer(for: Schema(versionedSchema: StillmoonSchemaV1.self),
                                  configurations: [health, account])
    }

    private static func configuration(_ name: String, _ models: [any PersistentModel.Type],
                                      inMemory: Bool, directory: URL?) -> ModelConfiguration {
        let schema = Schema(models)
        if inMemory || directory == nil {
            return ModelConfiguration(name, schema: schema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
        }
        return ModelConfiguration(name, schema: schema, url: directory!.appendingPathComponent("\(name).store"),
                                  allowsSave: true, cloudKitDatabase: .none)
    }
}

enum LocalOwner {
    /// Placeholder owner until Plan 5 signs users in.
    static let id = "local"
}

/// Owner-scoped access to everything stored on this iPhone.
final class LocalStore {
    let container: ModelContainer
    let ownerID: String
    private var context: ModelContext { container.mainContext }

    init(container: ModelContainer, ownerID: String) {
        self.container = container
        self.ownerID = ownerID
    }

    // MARK: Check-ins

    func checkIns() -> [CheckIn] {
        let owner = ownerID
        let descriptor = FetchDescriptor<CheckInRecord>(
            predicate: #Predicate { $0.ownerID == owner },
            sortBy: [SortDescriptor(\.date, order: .reverse)])
        return fetch(descriptor).map(\.value)
    }

    func todayCheckIn(now: Date, calendar: Calendar) -> CheckIn? {
        checkIns().first { calendar.isDate($0.date, inSameDayAs: now) }
    }

    func saveCheckIn(_ checkIn: CheckIn) {
        let owner = ownerID, id = checkIn.id
        let existing = fetch(FetchDescriptor<CheckInRecord>(predicate: #Predicate { $0.ownerID == owner && $0.id == id })).first
        if let existing { existing.update(from: checkIn) } else { context.insert(CheckInRecord(ownerID: owner, checkIn: checkIn)) }
        save()
    }

    // MARK: Journal

    func journalEntries() -> [JournalEntry] {
        let owner = ownerID
        let descriptor = FetchDescriptor<JournalEntryRecord>(
            predicate: #Predicate { $0.ownerID == owner },
            sortBy: [SortDescriptor(\.wakeTime, order: .reverse)])
        return fetch(descriptor).map(\.value)
    }

    func saveJournalEntry(_ entry: JournalEntry) {
        let owner = ownerID, id = entry.id
        let existing = fetch(FetchDescriptor<JournalEntryRecord>(predicate: #Predicate { $0.ownerID == owner && $0.id == id })).first
        if let existing { existing.update(from: entry) } else { context.insert(JournalEntryRecord(ownerID: owner, entry: entry)) }
        save()
    }

    func deleteJournalEntry(id: UUID) {
        let owner = ownerID
        for record in fetch(FetchDescriptor<JournalEntryRecord>(predicate: #Predicate { $0.ownerID == owner && $0.id == id })) {
            context.delete(record)
        }
        save()
    }

    // MARK: Completions and feedback (append-only events)

    func completions() -> [ExerciseCompletion] {
        let owner = ownerID
        let descriptor = FetchDescriptor<CompletionRecord>(
            predicate: #Predicate { $0.ownerID == owner },
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)])
        return fetch(descriptor).map(\.value)
    }

    func addCompletion(_ completion: ExerciseCompletion) {
        let owner = ownerID, id = completion.id
        guard fetch(FetchDescriptor<CompletionRecord>(predicate: #Predicate { $0.ownerID == owner && $0.id == id })).isEmpty else { return }
        context.insert(CompletionRecord(ownerID: owner, completion: completion))
        save()
    }

    func feedback() -> [RecommendationFeedback] {
        let owner = ownerID
        let descriptor = FetchDescriptor<FeedbackRecord>(
            predicate: #Predicate { $0.ownerID == owner },
            sortBy: [SortDescriptor(\.at)])
        return fetch(descriptor).map(\.value)
    }

    func addFeedback(_ feedback: RecommendationFeedback) {
        let owner = ownerID, id = feedback.id
        guard fetch(FetchDescriptor<FeedbackRecord>(predicate: #Predicate { $0.ownerID == owner && $0.id == id })).isEmpty else { return }
        context.insert(FeedbackRecord(ownerID: owner, feedback: feedback))
        save()
    }

    // MARK: Saved items

    func savedItemIDs() -> Set<String> {
        let owner = ownerID
        let records = fetch(FetchDescriptor<SavedItemRecord>(predicate: #Predicate { $0.ownerID == owner && $0.isSaved == true }))
        return Set(records.map(\.itemID))
    }

    func setSaved(_ itemID: String, _ saved: Bool, at date: Date) {
        let owner = ownerID
        if let existing = fetch(FetchDescriptor<SavedItemRecord>(predicate: #Predicate { $0.ownerID == owner && $0.itemID == itemID })).first {
            existing.isSaved = saved
            existing.updatedAt = date
        } else {
            context.insert(SavedItemRecord(ownerID: owner, itemID: itemID, isSaved: saved, updatedAt: date))
        }
        save()
    }

    // MARK: Sound sessions

    func startSoundSession(at date: Date) -> UUID {
        let record = SoundSessionRecord(ownerID: ownerID, startedAt: date)
        context.insert(record)
        save()
        return record.id
    }

    func endSoundSession(_ id: UUID, at date: Date) {
        let owner = ownerID
        fetch(FetchDescriptor<SoundSessionRecord>(predicate: #Predicate { $0.ownerID == owner && $0.id == id })).first?.endedAt = date
        save()
    }

    func recordInterruption(sessionID id: UUID) {
        let owner = ownerID
        if let record = fetch(FetchDescriptor<SoundSessionRecord>(predicate: #Predicate { $0.ownerID == owner && $0.id == id })).first {
            record.interruptions += 1
        }
        save()
    }

    func openSessionID() -> UUID? {
        let owner = ownerID
        return fetch(FetchDescriptor<SoundSessionRecord>(predicate: #Predicate { $0.ownerID == owner && $0.endedAt == nil })).first?.id
    }

    /// Ends sessions left open by a crash or force quit, at their last event (or start) time.
    func closeOrphanedSessions() {
        let owner = ownerID
        for session in fetch(FetchDescriptor<SoundSessionRecord>(predicate: #Predicate { $0.ownerID == owner && $0.endedAt == nil })) {
            let sid = session.id
            let last = fetch(FetchDescriptor<SoundEventRecord>(
                predicate: #Predicate { $0.ownerID == owner && $0.sessionID == sid },
                sortBy: [SortDescriptor(\.at, order: .reverse)])).first?.at
            session.endedAt = last ?? session.startedAt
        }
        save()
    }

    // MARK: Sound events

    func addSoundEvents(_ events: [SoundEvent], sessionID: UUID) {
        guard !events.isEmpty else { return }
        for event in events { context.insert(SoundEventRecord(ownerID: ownerID, sessionID: sessionID, event: event)) }
        save()
    }

    func soundEvents(from start: Date, to end: Date) -> [SoundEvent] {
        let owner = ownerID
        let descriptor = FetchDescriptor<SoundEventRecord>(
            predicate: #Predicate { $0.ownerID == owner && $0.at >= start && $0.at < end },
            sortBy: [SortDescriptor(\.at)])
        return fetch(descriptor).map(\.value)
    }

    func setCorrection(_ correction: SoundCorrection, forEvent id: UUID) {
        let owner = ownerID
        fetch(FetchDescriptor<SoundEventRecord>(predicate: #Predicate { $0.ownerID == owner && $0.id == id })).first?.correctionRaw = correction.rawValue
        save()
    }

    // MARK: Deletion

    /// Removes this owner's records only.
    func deleteAllData() {
        let owner = ownerID
        do {
            try context.delete(model: CheckInRecord.self, where: #Predicate { $0.ownerID == owner })
            try context.delete(model: JournalEntryRecord.self, where: #Predicate { $0.ownerID == owner })
            try context.delete(model: CompletionRecord.self, where: #Predicate { $0.ownerID == owner })
            try context.delete(model: FeedbackRecord.self, where: #Predicate { $0.ownerID == owner })
            try context.delete(model: SavedItemRecord.self, where: #Predicate { $0.ownerID == owner })
            try context.delete(model: SoundSessionRecord.self, where: #Predicate { $0.ownerID == owner })
            try context.delete(model: SoundEventRecord.self, where: #Predicate { $0.ownerID == owner })
        } catch {
            assertionFailure("Delete failed: \(error)")
        }
        save()
    }

    // MARK: Helpers

    private func fetch<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) -> [T] {
        do { return try context.fetch(descriptor) } catch {
            assertionFailure("Fetch failed: \(error)")
            return []
        }
    }

    private func save() {
        do { try context.save() } catch { assertionFailure("Save failed: \(error)") }
    }
}
