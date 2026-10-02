import Foundation
import Testing
import StillmoonCore
@testable import Stillmoon

struct NightDetailTests {
    let morning = TestEnv.d(2026, 10, 2, 9)

    func report(source: String = "Apple Watch", samples: [SleepSample]? = nil) -> NightReport {
        SleepReportBuilder.build(samples: samples ?? FakeHealthSource.sampleNight(endingOn: morning, calendar: TestEnv.cal, source: source),
                                 window: NightWindow.forMorning(of: morning, calendar: TestEnv.cal))!
    }

    @Test func stageRowsInDisplayOrder() {
        let rows = NightSummary.stageRows(report())
        #expect(rows.map(\.stage) == [.awake, .rem, .core, .deep])
        #expect(rows.first { $0.stage == .deep }?.seconds == 3600)
    }

    @Test func stageRowsEmptyWithoutDetail() {
        let phone = [SleepSample(stage: .asleepUnspecified, start: TestEnv.d(2026, 10, 1, 23), end: TestEnv.d(2026, 10, 2, 7), sourceName: "iPhone")]
        #expect(NightSummary.stageRows(report(samples: phone)).isEmpty)
        #expect(NightSummary.estimateLine(report(samples: phone)) == "iPhone estimated 8 h asleep")
    }

    @Test func estimateLineNamesTheSource() {
        #expect(NightSummary.estimateLine(report()) == "Apple Watch estimated 7 h 20 m asleep")
    }

    @Test func gapLineIsPlain() {
        let gap = DateInterval(start: TestEnv.d(2026, 10, 2, 1), end: TestEnv.d(2026, 10, 2, 2))
        let line = NightSummary.gapLine(gap)
        #expect(line.hasPrefix("No data from "))
        #expect(!line.contains("error"))
    }

    @Test func timelineDescriptionListsStagesInOrder() {
        let text = NightSummary.timelineDescription(report())
        #expect(text.hasPrefix("Core "))
        #expect(text.contains("Deep "))
        #expect(text.filter { $0 == "," }.count == 4)
    }

    @Test func incompleteNoteOnlyWithGaps() {
        #expect(NightSummary.incompleteNote(report()) == nil)
        let gappy = [
            SleepSample(stage: .core, start: TestEnv.d(2026, 10, 1, 23), end: TestEnv.d(2026, 10, 2, 1), sourceName: "Apple Watch"),
            SleepSample(stage: .core, start: TestEnv.d(2026, 10, 2, 2), end: TestEnv.d(2026, 10, 2, 7), sourceName: "Apple Watch"),
        ]
        #expect(NightSummary.incompleteNote(report(samples: gappy)) != nil)
    }

    @Test func soundCopy() {
        #expect(SoundLabel.speechLike.title == "Speech-like sound")
        #expect(SoundCorrection.someoneElse.title == "Someone else")
        #expect(SoundCorrection.none.title == nil)
        #expect(NightSummary.soundCountLine(0) == nil)
        #expect(NightSummary.soundCountLine(1) == "1 sound noted")
        #expect(NightSummary.soundCountLine(2) == "2 sounds noted")
    }
}
