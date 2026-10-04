import Foundation
import Testing
import StillmoonCore
@testable import Stillmoon

struct JourneyModelTests {
    let now = TestEnv.d(2026, 10, 2, 12) // Friday; week began Sunday 2026-09-27

    @Test func summarisesWeekAndRecent() throws {
        let store = try TestEnv.store()
        store.addCompletion(ExerciseCompletion(exerciseID: "breath", category: .windDown, completedAt: TestEnv.d(2026, 9, 28, 22)))
        store.addCompletion(ExerciseCompletion(exerciseID: "scan", category: .windDown, completedAt: TestEnv.d(2026, 10, 1, 22)))
        store.addCompletion(ExerciseCompletion(exerciseID: "gone", category: .windDown, completedAt: TestEnv.d(2026, 9, 20, 22)))
        let model = JourneyModel(store: store, settings: TestEnv.settings(), catalog: TestEnv.catalog,
                                 now: { now }, calendar: TestEnv.cal)
        model.refresh()
        #expect(model.summary.windDownsThisWeek == 2)
        #expect(model.summary.totalWindDowns == 3)
        #expect(model.summary.journeyStage == 2)
        #expect(model.stageName == "Quiet meadow")
        #expect(model.recent.map(\.title) == ["Body scan", "Gentle breathing"]) // unknown ids are skipped
        let litStars = model.sky.flatMap(\.stars).filter { (star: SkyStar) in star.state == .lit }
        #expect(litStars.count == 3)
        #expect(model.nextWindDown?.title == "Gentle breathing")
    }

    @Test func respectsWeeklyGoalAndHide() throws {
        let settings = TestEnv.settings()
        settings.settings.weeklyGoal = 5
        settings.settings.hideProgress = true
        let model = JourneyModel(store: try TestEnv.store(), settings: settings, catalog: TestEnv.catalog,
                                 now: { now }, calendar: TestEnv.cal)
        model.refresh()
        #expect(model.summary.weeklyGoal == 5)
        #expect(model.isHidden)
        #expect(model.stageName == "The path begins")
    }

    @Test func deleteAllLocalDataKeepsOnboarding() throws {
        let settings = TestEnv.settings()
        settings.settings.hasOnboarded = true
        settings.settings.weeklyGoal = 6
        let store = try TestEnv.store()
        store.addCompletion(ExerciseCompletion(exerciseID: "breath", category: .windDown, completedAt: now))
        let env = AppEnvironment(store: store, settings: settings, catalog: TestEnv.catalog)
        env.deleteAllLocalData()
        #expect(store.completions().isEmpty)
        #expect(settings.settings.hasOnboarded)
        #expect(settings.settings.weeklyGoal == 3)
    }
}
