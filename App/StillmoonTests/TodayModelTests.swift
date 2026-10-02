import Foundation
import Testing
import StillmoonCore
@testable import Stillmoon

struct TodayModelTests {
    let now = TestEnv.d(2026, 10, 2, 9)

    func make(goal: Goal = .unwind) throws -> (TodayModel, LocalStore) {
        let store = try TestEnv.store()
        let settings = TestEnv.settings()
        settings.settings.goal = goal
        let model = TodayModel(store: store, settings: settings, catalog: TestEnv.catalog,
                               now: { now }, calendar: TestEnv.cal)
        return (model, store)
    }

    @Test(arguments: [(6, "Good morning"), (13, "Good afternoon"), (19, "Good evening"), (23, "It's late. Go gently."), (3, "It's late. Go gently.")])
    func greeting(hour: Int, text: String) {
        #expect(TodayModel.greeting(hour: hour) == text)
    }

    @Test func noDataGivesGoalBasedSuggestions() throws {
        let (m, _) = try make(goal: .unwind)
        m.refresh()
        #expect(m.recommendations.map(\.itemID) == ["breath", "scan"])
        #expect(m.recommendations.allSatisfy { $0.reason == RecommendationEngine.Reason.goal })
        #expect(m.recommendations.first?.title == "Gentle breathing")
        #expect(m.recommendations.first?.route == .exercise("breath"))
        #expect(m.lastNight == nil)
        #expect(m.todayCheckIn == nil)
    }

    @Test func wokeCheckInLeadsWithAwakeExercise() throws {
        let (m, _) = try make(goal: .consistency)
        m.saveCheckIn(CheckIn(date: now, restedness: 2, wokeDuringNight: true))
        #expect(m.recommendations.first?.itemID == "awake")
        #expect(m.recommendations.first?.reason == "You mentioned being awake during the night.")
        #expect(m.recommendations.dropFirst().first?.route == .article("steady-bedtime"))
    }

    @Test func secondCheckInSameDayUpdates() throws {
        let (m, store) = try make()
        m.saveCheckIn(CheckIn(date: now, restedness: 2, tenseAtBedtime: true))
        m.saveCheckIn(CheckIn(date: now.addingTimeInterval(600), restedness: 4))
        #expect(store.checkIns().count == 1)
        #expect(m.todayCheckIn?.restedness == 4)
        #expect(m.recommendations.first?.reason == RecommendationEngine.Reason.goal)
    }

    @Test func unwantedSuggestionDisappears() throws {
        let (m, _) = try make(goal: .unwind)
        m.refresh()
        m.rate("breath", .unwanted)
        #expect(m.recommendations.map(\.itemID) == ["scan"])
    }

    @Test func lastNightIsThisMorningsEntryOnly() throws {
        let (m, store) = try make()
        store.saveJournalEntry(JournalEntry(bedtime: TestEnv.d(2026, 9, 29, 23), wakeTime: TestEnv.d(2026, 9, 30, 7)))
        m.refresh()
        #expect(m.lastNight == nil)
        let tonight = JournalEntry(bedtime: TestEnv.d(2026, 10, 1, 23), wakeTime: TestEnv.d(2026, 10, 2, 7))
        m.saveJournalEntry(tonight)
        #expect(m.lastNight == tonight)
    }

    @Test func progressAndDifficultyCard() throws {
        let (m, store) = try make()
        store.addCompletion(ExerciseCompletion(exerciseID: "breath", category: .windDown, completedAt: TestEnv.d(2026, 10, 1, 22)))
        m.saveCheckIn(CheckIn(date: now, restedness: 2, persistentDifficulty: true))
        #expect(m.progress.windDownsThisWeek == 1)
        #expect(m.showsDifficultyCard)
    }

    @Test func awakeAtNightExerciseComesFromCatalog() throws {
        let (m, _) = try make()
        #expect(m.awakeAtNightExercise?.id == "awake")
    }
}
