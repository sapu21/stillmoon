import Testing
import StillmoonCore
@testable import Stillmoon

struct LumiDirectorTests {
    func progress(_ week: Int, goal: Int = 3, total: Int) -> ProgressSummary {
        ProgressSummary(windDownsThisWeek: week, weeklyGoal: goal, goalMet: week >= goal,
                        totalWindDowns: total, journeyStage: 1)
    }

    @Test func headerCountsDownToAFullMoon() {
        func text(_ p: ProgressSummary) -> String? {
            LumiDirector.todayHeader(progress: p, hideProgress: false, isNight: false).text
        }
        #expect(text(progress(2, total: 4)) == "One more wind-down fills this week's moon.")
        #expect(text(progress(0, total: 4)) == "3 more wind-downs fill this week's moon.")
        #expect(text(progress(3, total: 7)) == "This week's moon is full.")
        #expect(text(progress(5, total: 9)) == "This week's moon is full.")
        let first = LumiDirector.todayHeader(progress: progress(0, total: 0), hideProgress: false, isNight: false)
        #expect(first.mood == .wave)
        #expect(first.text == "Hi! Want to try a few calm minutes?")
    }

    @Test func hiddenProgressNeverShowsCounts() {
        let line = LumiDirector.todayHeader(progress: progress(1, total: 4), hideProgress: true, isNight: false)
        #expect(line.text == "Here whenever you need a calm minute.")
    }

    @Test func nightIsQuiet() {
        let header = LumiDirector.todayHeader(progress: progress(3, total: 9), hideProgress: false, isNight: true)
        #expect(header == LumiDirector.Line(mood: .sleepy, motion: .drift, text: nil))
        for level in 1...5 {
            let line = LumiDirector.checkIn(level: level, isNight: true)
            #expect(line.mood != .cheer)
            #expect(line.motion == .drift)
        }
    }

    @Test func checkInFollowsRestedness() {
        #expect(LumiDirector.checkIn(level: 1, isNight: false).mood == .concerned)
        #expect(LumiDirector.checkIn(level: 1, isNight: false).text == "Rough night. Let's go gently today.")
        #expect(LumiDirector.checkIn(level: 3, isNight: false).mood == .calm)
        #expect(LumiDirector.checkIn(level: 5, isNight: false)
                == LumiDirector.Line(mood: .cheer, motion: .bounce, text: "Wonderful! Hold on to that feeling."))
        #expect(LumiDirector.checkIn(level: 0, isNight: false) == LumiDirector.checkIn(level: 1, isNight: false))
        #expect(LumiDirector.checkIn(level: 8, isNight: false) == LumiDirector.checkIn(level: 5, isNight: false))
    }

    @Test func everyOnboardingStepHasALine() {
        for step in OnboardingModel.Step.allCases {
            #expect(LumiDirector.onboarding(step).text?.isEmpty == false)
        }
        #expect(LumiDirector.onboarding(.welcome).mood == .wave)
    }

    @Test func neverTalksAboutSleepMetrics() {
        let banned = ["score", "rem ", "deep", "hour", "asleep", "anxious", "stress", "streak"]
        #expect(LumiDirector.allLines.count > 15)
        for line in LumiDirector.allLines {
            for word in banned {
                #expect(!line.lowercased().contains(word), "\(line) mentions \(word)")
            }
        }
    }
}
