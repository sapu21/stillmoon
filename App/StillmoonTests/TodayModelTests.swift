import Foundation
import Testing
import StillmoonCore
@testable import Stillmoon

struct TodayModelTests {
    let now = TestEnv.d(2026, 10, 2, 9)

    func make(goal: Goal = .unwind, connected: Bool = false, samples: [SleepSample] = []) throws -> (TodayModel, LocalStore) {
        let store = try TestEnv.store()
        let settings = TestEnv.settings()
        settings.settings.goal = goal
        settings.settings.healthConnected = connected
        let health = FakeHealthSource(samples: samples)
        let model = TodayModel(store: store, settings: settings, catalog: TestEnv.catalog, health: health,
                               now: { now }, calendar: TestEnv.cal)
        return (model, store)
    }

    @Test func lastNightReportWhenConnected() async throws {
        let (m, _) = try make(connected: true, samples: FakeHealthSource.sampleNight(endingOn: now, calendar: TestEnv.cal))
        await m.refreshHealth()
        #expect(m.lastNightReport?.primarySource == "Apple Watch")
    }

    @Test func noReportWhenNotConnected() async throws {
        let (m, _) = try make(connected: false, samples: FakeHealthSource.sampleNight(endingOn: now, calendar: TestEnv.cal))
        await m.refreshHealth()
        #expect(m.lastNightReport == nil)
    }

    @Test func variedHealthBedtimesSuggestRoutine() async throws {
        // Four nights, bed at 22:00, 23:45, 00:30 and 22:15 (spread 150 min); now is 2026-10-02 09:00.
        let starts = [TestEnv.d(2026, 9, 28, 22), TestEnv.d(2026, 9, 29, 23, 45),
                      TestEnv.d(2026, 10, 1, 0, 30), TestEnv.d(2026, 10, 1, 22, 15)]
        let samples = starts.map { SleepSample(stage: .core, start: $0, end: $0.addingTimeInterval(7 * 3600), sourceName: "Apple Watch") }
        let (m, _) = try make(goal: .understandSleep, connected: true, samples: samples)
        await m.refreshHealth()
        #expect(m.recommendations.first?.reason == "Your recorded bedtimes varied this week.")
    }

    @Test func disconnectingClearsLastNightReport() async throws {
        let (m, _, settings) = try makeWithSettings(connected: true, samples: FakeHealthSource.sampleNight(endingOn: now, calendar: TestEnv.cal))
        await m.refreshHealth()
        #expect(m.lastNightReport != nil)
        settings.settings.healthConnected = false
        await m.refreshHealth()
        #expect(m.lastNightReport == nil)
        #expect(!m.recommendations.isEmpty)
    }

    @Test func healthAndJournalBedtimesDedupedPerNight() {
        let journal = [TestEnv.d(2026, 10, 1, 23)]
        let health = [TestEnv.d(2026, 10, 1, 23, 20), TestEnv.d(2026, 9, 30, 22)]
        let combined = TodayModel.combinedBedtimes(journal: journal, health: health, calendar: TestEnv.cal)
        #expect(combined.sorted() == [TestEnv.d(2026, 9, 30, 22), TestEnv.d(2026, 10, 1, 23, 20)])
    }

    func makeWithSettings(connected: Bool = false, samples: [SleepSample] = []) throws -> (TodayModel, LocalStore, SettingsStore) {
        let store = try TestEnv.store()
        let settings = TestEnv.settings()
        settings.settings.healthConnected = connected
        let model = TodayModel(store: store, settings: settings, catalog: TestEnv.catalog,
                               health: FakeHealthSource(samples: samples),
                               now: { now }, calendar: TestEnv.cal)
        return (model, store, settings)
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

    @Test func nightPhaseBeforeAndAfterBedtime() throws {
        let (m, _, settings) = try makeWithSettings()
        settings.settings.bedtime = ClockTime(hour: 23, minute: 0)
        #expect(m.nightPhase(at: TestEnv.d(2026, 10, 2, 22, 15)) == .windDown)
        #expect(m.nightPhase(at: TestEnv.d(2026, 10, 2, 23, 30)) == .awake)
        #expect(m.nightPhase(at: TestEnv.d(2026, 10, 3, 2, 0)) == .awake)
        settings.settings.bedtime = nil
        #expect(m.nightPhase(at: TestEnv.d(2026, 10, 2, 21, 30)) == .windDown)
    }

    @Test func windDownSuggestionPrefersEngineReason() throws {
        let (m, _) = try make(goal: .unwind)
        m.refresh()
        #expect(m.windDownSuggestion?.itemID == "breath")
        #expect(m.windDownSuggestion?.reason == RecommendationEngine.Reason.goal)
    }

    @Test func snoringNoteShowsOnceAfterFiveNights() throws {
        let (m, store) = try make()
        let s = store.startSoundSession(at: TestEnv.d(2026, 9, 26, 23))
        for day in 26...30 {
            let e = SoundEvent(label: .snoringLike, at: TestEnv.d(2026, 9, day, 23, 30), confidence: 0.8, correction: .wasMe)
            store.addSoundEvents([e], sessionID: s)
        }
        m.refresh()
        #expect(m.showsSnoringNote)
        m.dismissSnoringNote()
        #expect(!m.showsSnoringNote)
    }

    @Test func metaDescribesExercisesOnly() throws {
        let model = TodayModel(store: try TestEnv.store(), settings: TestEnv.settings(), catalog: TestEnv.catalog)
        let exercise = ResolvedRecommendation(itemID: "breath", kind: .exercise, title: "Gentle breathing", reason: "")
        let article = ResolvedRecommendation(itemID: "steady-bedtime", kind: .article, title: "Keeping a steady bedtime", reason: "")
        #expect(model.meta(for: exercise) == "1 min · Text")
        #expect(model.meta(for: article) == nil)
    }
}
