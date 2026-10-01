import Foundation
import Testing
@testable import StillmoonCore

struct RecommendationTests {
    let catalog = [
        CatalogItem(id: "pmr", kind: .exercise, title: "Progressive muscle relaxation", tags: [.relaxation]),
        CatalogItem(id: "breath", kind: .exercise, title: "Gentle breathing", tags: [.relaxation]),
        CatalogItem(id: "awake-5", kind: .exercise, title: "Five quiet minutes", tags: [.awakeAtNight]),
        CatalogItem(id: "timing", kind: .article, title: "Keeping a steady bedtime", tags: [.routine]),
        CatalogItem(id: "stages", kind: .article, title: "What your watch estimates", tags: [.sleepData]),
    ]

    func run(goal: Goal = .unwind, checkIn: CheckIn? = nil, bedtimes: [Date] = [],
             feedback: [RecommendationFeedback] = [], catalog: [CatalogItem]? = nil) -> [Recommendation] {
        RecommendationEngine.recommend(
            RecommendationInput(goal: goal, todayCheckIn: checkIn, recentBedtimes: bedtimes,
                                feedback: feedback, catalog: catalog ?? self.catalog),
            calendar: T.cal)
    }

    func checkIn(tense: Bool = false, woke: Bool = false) -> CheckIn {
        CheckIn(date: T.d(2026, 10, 2, 8), restedness: 3, tenseAtBedtime: tense, wokeDuringNight: woke)
    }

    func fb(_ id: String, _ r: FeedbackRating) -> RecommendationFeedback {
        RecommendationFeedback(itemID: id, rating: r, at: T.d(2026, 10, 1))
    }

    @Test func tenseLeadsWithRelaxation() {
        let r = run(goal: .understandSleep, checkIn: checkIn(tense: true))
        #expect(r.first == Recommendation(itemID: "pmr", reason: RecommendationEngine.Reason.tense))
        #expect(r.first?.reason == "You mentioned feeling tense before bed.")
    }

    @Test func tenseAndWokeGiveBoth() {
        let r = run(goal: .understandSleep, checkIn: checkIn(tense: true, woke: true))
        #expect(r.map(\.itemID) == ["pmr", "awake-5", "stages"])
        #expect(r[1].reason == "You mentioned being awake during the night.")
        #expect(r[2].reason == "Based on the goal you chose.")
    }

    @Test func sparseDataFallsBackToGoal() {
        let r = run(goal: .unwind)
        #expect(r.map(\.itemID) == ["pmr", "breath"])
        #expect(r.allSatisfy { $0.reason == RecommendationEngine.Reason.goal })
    }

    @Test func unwantedIsNeverShown() {
        let r = run(goal: .unwind, checkIn: checkIn(tense: true), feedback: [fb("pmr", .unwanted)])
        #expect(!r.contains { $0.itemID == "pmr" })
        #expect(r.first?.itemID == "breath")
    }

    @Test func dismissedTwiceIsDemoted() {
        let r = run(checkIn: checkIn(tense: true), feedback: [fb("pmr", .irrelevant), fb("pmr", .irrelevant)])
        #expect(r.map(\.itemID) == ["breath", "pmr"])
    }

    @Test func dismissedOnceKeepsItsPlace() {
        let r = run(checkIn: checkIn(tense: true), feedback: [fb("pmr", .irrelevant)])
        #expect(r.first?.itemID == "pmr")
    }

    @Test func neverMoreThanThreeAndNoRepeats() {
        let many = (0..<10).map { CatalogItem(id: "r\($0)", kind: .exercise, title: "R\($0)", tags: [.relaxation]) }
        let r = run(goal: .unwind, checkIn: checkIn(tense: true), catalog: many)
        #expect(r.count == 3)
        #expect(Set(r.map(\.itemID)).count == 3)
    }

    @Test func emptyCatalogGivesNothing() {
        #expect(run(checkIn: checkIn(tense: true), catalog: []).isEmpty)
    }

    @Test func variedBedtimesAcrossMidnightSuggestRoutine() {
        let beds = [T.d(2026, 9, 27, 22), T.d(2026, 9, 28, 23, 45), T.d(2026, 9, 30, 0, 30), T.d(2026, 9, 30, 22, 15)]
        let r = run(goal: .understandSleep, bedtimes: beds)
        #expect(r.first == Recommendation(itemID: "timing", reason: "Your recorded bedtimes varied this week."))
    }

    @Test func steadyBedtimesAroundMidnightAreNotVaried() {
        let beds = [T.d(2026, 9, 27, 23, 50), T.d(2026, 9, 29, 0, 10), T.d(2026, 9, 29, 23, 55), T.d(2026, 10, 1, 0, 5)]
        #expect(!RecommendationEngine.bedtimesVary(beds, calendar: T.cal))
    }

    @Test func fewerThanFourBedtimesAreNotEnough() {
        let beds = [T.d(2026, 9, 27, 21), T.d(2026, 9, 28, 1), T.d(2026, 9, 29, 23)]
        #expect(!RecommendationEngine.bedtimesVary(beds, calendar: T.cal))
    }
}
