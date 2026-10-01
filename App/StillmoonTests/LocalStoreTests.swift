import Foundation
import Testing
import StillmoonCore
@testable import Stillmoon

struct LocalStoreTests {
    @Test func checkInsComeBackNewestFirst() throws {
        let store = try TestEnv.store()
        store.saveCheckIn(CheckIn(date: TestEnv.d(2026, 10, 1, 8), restedness: 2))
        store.saveCheckIn(CheckIn(date: TestEnv.d(2026, 10, 2, 8), restedness: 4))
        #expect(store.checkIns().map(\.restedness) == [4, 2])
    }

    @Test func savingSameCheckInIdUpdates() throws {
        let store = try TestEnv.store()
        var c = CheckIn(date: TestEnv.d(2026, 10, 2, 8), restedness: 2)
        store.saveCheckIn(c)
        c.restedness = 5
        c.note = "better"
        store.saveCheckIn(c)
        #expect(store.checkIns().count == 1)
        #expect(store.checkIns().first?.restedness == 5)
        #expect(store.checkIns().first?.note == "better")
    }

    @Test func todayCheckInMatchesCalendarDay() throws {
        let store = try TestEnv.store()
        store.saveCheckIn(CheckIn(date: TestEnv.d(2026, 10, 1, 8), restedness: 2))
        #expect(store.todayCheckIn(now: TestEnv.d(2026, 10, 2, 9), calendar: TestEnv.cal) == nil)
        store.saveCheckIn(CheckIn(date: TestEnv.d(2026, 10, 2, 7), restedness: 3))
        #expect(store.todayCheckIn(now: TestEnv.d(2026, 10, 2, 9), calendar: TestEnv.cal)?.restedness == 3)
    }

    @Test func ownersAreIsolated() throws {
        let container = try TestEnv.container()
        let a = try TestEnv.store(owner: "user-a", container: container)
        let b = try TestEnv.store(owner: "user-b", container: container)
        a.saveCheckIn(CheckIn(date: TestEnv.d(2026, 10, 2, 8), restedness: 4))
        a.saveJournalEntry(JournalEntry(bedtime: TestEnv.d(2026, 10, 1, 23), wakeTime: TestEnv.d(2026, 10, 2, 7)))
        a.addCompletion(ExerciseCompletion(exerciseID: "breath", category: .windDown, completedAt: TestEnv.d(2026, 10, 1, 22)))
        a.addFeedback(RecommendationFeedback(itemID: "breath", rating: .helpful, at: TestEnv.d(2026, 10, 2, 8)))
        a.setSaved("breath", true, at: TestEnv.d(2026, 10, 2, 8))
        #expect(b.checkIns().isEmpty)
        #expect(b.journalEntries().isEmpty)
        #expect(b.completions().isEmpty)
        #expect(b.feedback().isEmpty)
        #expect(b.savedItemIDs().isEmpty)
    }

    @Test func deleteAllOnlyRemovesOwnersData() throws {
        let container = try TestEnv.container()
        let a = try TestEnv.store(owner: "user-a", container: container)
        let b = try TestEnv.store(owner: "user-b", container: container)
        for s in [a, b] {
            s.saveCheckIn(CheckIn(date: TestEnv.d(2026, 10, 2, 8), restedness: 4))
            s.addCompletion(ExerciseCompletion(exerciseID: "breath", category: .windDown, completedAt: TestEnv.d(2026, 10, 1, 22)))
            s.setSaved("breath", true, at: TestEnv.d(2026, 10, 2, 8))
        }
        a.deleteAllData()
        #expect(a.checkIns().isEmpty)
        #expect(a.completions().isEmpty)
        #expect(a.savedItemIDs().isEmpty)
        #expect(b.checkIns().count == 1)
        #expect(b.completions().count == 1)
        #expect(b.savedItemIDs() == ["breath"])
    }

    @Test func completionsKeepCategoryAndId() throws {
        let store = try TestEnv.store()
        let c = ExerciseCompletion(exerciseID: "awake", category: .awakeAtNight, completedAt: TestEnv.d(2026, 10, 2, 3))
        store.addCompletion(c)
        store.addCompletion(c) // same event delivered twice is stored once
        #expect(store.completions() == [c])
    }

    @Test func journalSaveUpdateDelete() throws {
        let store = try TestEnv.store()
        var e = JournalEntry(bedtime: TestEnv.d(2026, 10, 1, 23), wakeTime: TestEnv.d(2026, 10, 2, 7))
        store.saveJournalEntry(e)
        e.note = "woke once"
        store.saveJournalEntry(e)
        #expect(store.journalEntries() == [e])
        store.deleteJournalEntry(id: e.id)
        #expect(store.journalEntries().isEmpty)
    }

    @Test func savedItemsToggle() throws {
        let store = try TestEnv.store()
        store.setSaved("breath", true, at: TestEnv.d(2026, 10, 2, 8))
        store.setSaved("scan", true, at: TestEnv.d(2026, 10, 2, 8))
        store.setSaved("breath", false, at: TestEnv.d(2026, 10, 2, 9))
        #expect(store.savedItemIDs() == ["scan"])
    }

    @Test func feedbackRoundTrips() throws {
        let store = try TestEnv.store()
        let f = RecommendationFeedback(itemID: "breath", rating: .unwanted, at: TestEnv.d(2026, 10, 2, 8))
        store.addFeedback(f)
        #expect(store.feedback() == [f])
    }
}
