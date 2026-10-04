import Foundation
import Testing
import StillmoonCore
@testable import Stillmoon

struct StageBarTests {
    func sample(_ stage: SleepStage, _ from: Int, _ to: Int) -> SleepSample {
        SleepSample(stage: stage, start: TestEnv.d(2026, 10, 2, 0, from), end: TestEnv.d(2026, 10, 2, 0, to), sourceName: "Watch")
    }

    @Test func mergesNeighboursAndSkipsInBed() {
        let segments = StageBar.segments([
            sample(.inBed, 0, 60), sample(.core, 0, 10), sample(.core, 10, 20), sample(.deep, 20, 30), sample(.awake, 30, 40),
        ])
        #expect(segments.map(\.stage) == [.core, .deep, .awake])
        #expect(abs(segments[0].fraction - 0.5) < 0.001)
        #expect(abs(segments.map(\.fraction).reduce(0, +) - 1) < 0.001)
    }

    @Test func emptyTimelineHasNoSegments() {
        #expect(StageBar.segments([]).isEmpty)
        #expect(StageBar.segments([sample(.inBed, 0, 30)]).isEmpty)
    }
}
