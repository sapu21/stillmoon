import Foundation
import Testing
import StillmoonCore
@testable import Stillmoon

struct OnboardingModelTests {
    @Test func fullPathSavesGoalAndSchedule() {
        let settings = TestEnv.settings()
        let m = OnboardingModel(settings: settings)
        #expect(m.step == .welcome)
        #expect(!m.canGoBack)
        m.next()
        m.chooseGoal(.nightWaking)
        #expect(m.step == .schedule)
        m.bedtime = ClockTime(hour: 23, minute: 30)
        m.wakeTime = ClockTime(hour: 6, minute: 45)
        m.next()
        #expect(m.step == .privacy)
        m.next()
        #expect(m.step == .firstExercise)
        m.finish()
        #expect(settings.settings.goal == .nightWaking)
        #expect(settings.settings.bedtime == ClockTime(hour: 23, minute: 30))
        #expect(settings.settings.wakeTime == ClockTime(hour: 6, minute: 45))
        #expect(settings.settings.hasOnboarded)
    }

    @Test func skippingScheduleLeavesDefaults() {
        let settings = TestEnv.settings()
        let m = OnboardingModel(settings: settings)
        m.next()
        m.chooseGoal(.unwind)
        m.skipSchedule()
        #expect(m.step == .privacy)
        #expect(settings.settings.bedtime == nil)
        #expect(settings.settings.wakeTime == nil)
    }

    @Test func backMovesOneStepAndStopsAtWelcome() {
        let m = OnboardingModel(settings: TestEnv.settings())
        m.next()
        m.next()
        #expect(m.step == .schedule)
        m.back()
        #expect(m.step == .goal)
        m.back()
        m.back()
        #expect(m.step == .welcome)
    }

    @Test func firstExerciseExistsInBundledCatalog() throws {
        #expect(try ContentStore.loadBundled().exercise(id: OnboardingModel.firstExerciseID) != nil)
    }
}
