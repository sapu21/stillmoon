import Testing
@testable import Stillmoon

struct SkyPathTests {
    @Test func stagesHoldOneMoreStarEachTime() {
        let stages = SkyPath.stages(totalWindDowns: 0)
        #expect(stages.map(\.stars.count) == [1, 2, 3, 4, 5, 6])
        #expect(stages.map(\.name) == ["First light", "Quiet meadow", "Willow bend", "Still lake", "Hilltop", "Moonrise"])
        #expect(stages[0].stars[0].state == .next)
    }

    @Test func starsLightInOrder() {
        let stages = SkyPath.stages(totalWindDowns: 4)
        #expect(stages[0].stars.map(\.state) == [.lit])
        #expect(stages[1].stars.map(\.state) == [.lit, .lit])
        #expect(stages[2].stars.map(\.state) == [.lit, .next, .locked])
        #expect(stages[2].litCount == 1)
        #expect(stages.flatMap(\.stars).map(\.index) == Array(0..<21))
    }

    @Test func fullSkyHasNoNextStar() {
        for total in [21, 40] {
            let stars = SkyPath.stages(totalWindDowns: total).flatMap(\.stars)
            #expect(stars.allSatisfy { $0.state == .lit })
        }
    }

    @Test func stageOfStar() {
        #expect(SkyPath.stage(ofStar: 0) == 1)
        #expect(SkyPath.stage(ofStar: 3) == 3)
        #expect(SkyPath.stage(ofStar: 20) == 6)
        #expect(SkyPath.stage(ofStar: 21) == nil)
        #expect(SkyPath.stage(ofStar: -1) == nil)
    }

    @Test func pathZigzags() {
        #expect(SkyPath.xOffset(forStar: 0) == 0)
        #expect(SkyPath.xOffset(forStar: 2) == -90)
        #expect(SkyPath.xOffset(forStar: 8) == SkyPath.xOffset(forStar: 0))
    }
}
