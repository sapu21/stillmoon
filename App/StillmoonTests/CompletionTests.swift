import Testing
import StillmoonCore
@testable import Stillmoon

struct CompletionTests {
    @Test func celebratesOnlyDaytimeWindDowns() {
        #expect(CompletionStyle.style(for: .windDown, isNight: false) == .celebrate)
        #expect(CompletionStyle.style(for: .windDown, isNight: true) == .quiet)
        #expect(CompletionStyle.style(for: .awakeAtNight, isNight: false) == .quiet)
        #expect(CompletionStyle.style(for: .morningReset, isNight: false) == .quiet)
    }

    @Test func summaryNamesTheStarJustLit() {
        let progress = ProgressSummary(windDownsThisWeek: 3, weeklyGoal: 3, goalMet: true, totalWindDowns: 5, journeyStage: 3)
        let summary = CompletionSummary(progress: progress, playedSeconds: 290, savedToHealth: true)
        #expect(summary.minutes == 5)
        #expect(summary.windDownsThisWeek == 3)
        #expect(summary.star == CompletionSummary.Star(stageName: "Willow bend", litInStage: 2, starsInStage: 3))
        #expect(summary.savedToHealth)
    }

    @Test func summaryPastTheLastStarHasNoStar() {
        let progress = ProgressSummary(windDownsThisWeek: 1, weeklyGoal: 3, goalMet: false, totalWindDowns: 22, journeyStage: 6)
        #expect(CompletionSummary(progress: progress, playedSeconds: 20, savedToHealth: false).star == nil)
        #expect(CompletionSummary(progress: progress, playedSeconds: 20, savedToHealth: false).minutes == 1)
    }
}

struct CompletionReviewFixTests {
    let progress = ProgressSummary(windDownsThisWeek: 2, weeklyGoal: 3, goalMet: false, totalWindDowns: 4, journeyStage: 3)

    @Test func hiddenProgressShowsNoCountsOrStars() {
        let hidden = CompletionSummary(progress: progress, playedSeconds: 300, savedToHealth: false, hideProgress: true)
        #expect(!hidden.showsProgress)
        #expect(hidden.star == nil)
        #expect(CompletionSummary(progress: progress, playedSeconds: 300, savedToHealth: false).showsProgress)
    }

    @Test func healthLineNeverClaimsAConfirmedSave() {
        #expect(CompletionSummary(progress: progress, playedSeconds: 300, savedToHealth: false).healthLine == nil)
        let line = CompletionSummary(progress: progress, playedSeconds: 300, savedToHealth: true).healthLine
        #expect(line == "Mindful Minutes go to Apple Health when you've allowed it.")
    }
}
