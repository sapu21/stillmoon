import Foundation
import Testing
@testable import StillmoonCore

struct ProgressTests {
    // 2026-10-02 is a Friday; the week (Sunday start) began 2026-09-27.
    let now = T.d(2026, 10, 2, 12)

    func wd(_ at: Date, id: UUID = UUID()) -> ExerciseCompletion {
        ExerciseCompletion(id: id, exerciseID: "breathing", category: .windDown, completedAt: at)
    }

    func summary(_ c: [ExerciseCompletion], goal: Int = 3) -> ProgressSummary {
        ProgressCalculator.summary(completions: c, weeklyGoal: goal, now: now, calendar: T.cal)
    }

    @Test func countsOnlyThisWeeksWindDowns() {
        let c = [
            wd(T.d(2026, 9, 26, 22)),      // Saturday, last week
            wd(T.d(2026, 9, 27, 0, 5)),    // Sunday, this week
            wd(T.d(2026, 10, 1, 22)),
            ExerciseCompletion(exerciseID: "reset", category: .morningReset, completedAt: T.d(2026, 10, 1, 7)),
        ]
        let s = summary(c)
        #expect(s.windDownsThisWeek == 2)
        #expect(s.totalWindDowns == 3)
        #expect(!s.goalMet)
    }

    @Test func meetsGoal() {
        let c = (0..<3).map { wd(T.d(2026, 9, 28 + $0, 22)) }
        #expect(summary(c).goalMet)
    }

    @Test func sameEventSyncedTwiceCountsOnce() {
        let id = UUID()
        let s = summary([wd(T.d(2026, 10, 1, 22), id: id), wd(T.d(2026, 10, 1, 22), id: id)])
        #expect(s.windDownsThisWeek == 1)
        #expect(s.totalWindDowns == 1)
    }

    @Test func goalBelowOneIsClamped() {
        let s = summary([wd(T.d(2026, 10, 1, 22))], goal: 0)
        #expect(s.weeklyGoal == 1)
        #expect(s.goalMet)
    }

    @Test(arguments: [(0, 0), (1, 1), (2, 1), (3, 2), (6, 3), (10, 4), (15, 5), (21, 6), (40, 6)])
    func journeyStages(total: Int, stage: Int) {
        let c = (0..<total).map { wd(T.d(2026, 1, 1).addingTimeInterval(Double($0) * 86400)) }
        #expect(summary(c).journeyStage == stage)
    }

    @Test func journeyNeverGoesBackward() {
        var c: [ExerciseCompletion] = []
        var last = 0
        for i in 0..<30 {
            c.append(wd(T.d(2026, 1, 1).addingTimeInterval(Double(i) * 86400)))
            let stage = summary(c).journeyStage
            #expect(stage >= last)
            last = stage
        }
    }
}
