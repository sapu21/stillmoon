import Foundation
import SwiftData
import StillmoonCore

enum StillmoonSchema {
    static func makeContainer(inMemory: Bool) throws -> ModelContainer {
        let schema = Schema([CheckInRecord.self, JournalEntryRecord.self, CompletionRecord.self,
                             FeedbackRecord.self, SavedItemRecord.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: config)
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
