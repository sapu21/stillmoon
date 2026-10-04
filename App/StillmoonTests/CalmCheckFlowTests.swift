import Foundation
import Testing
@testable import Stillmoon

struct CalmCheckFlowTests {
    let at = TestEnv.d(2026, 10, 4, 21)

    @Test func disabledGoesStraightToTheExercise() {
        let flow = CalmCheckFlow(exerciseID: "breath", at: at, enabled: false)
        #expect(flow.step == .exercise)
        #expect(!flow.offersCheckAgain)
        #expect(flow.savable == nil)
    }

    @Test func beforeAndAfterAreRecordedSeparately() {
        let flow = CalmCheckFlow(exerciseID: "breath", at: at, enabled: true)
        #expect(flow.step == .before)
        flow.recordTension(4)
        flow.recordPulse(.reading(bpm: 78.4, hrv: 31))
        flow.finishBefore()
        #expect(flow.step == .exercise)
        flow.recordTension(1) // ignored during the exercise
        #expect(flow.offersCheckAgain)
        flow.startAfter()
        #expect(flow.step == .after)
        flow.recordTension(2)
        flow.recordPulse(.reading(bpm: 66.2, hrv: 48))
        flow.finishAfter()
        #expect(flow.step == .done)
        #expect(!flow.offersCheckAgain)
        let check = flow.savable
        #expect(check?.tenseBefore == 4 && check?.tenseAfter == 2)
        #expect(check?.bpmBefore == 78.4 && check?.bpmAfter == 66.2)
        #expect(check?.hrvBefore == 31 && check?.hrvAfter == 48)
    }

    @Test func unclearReadingsAndSkipsSaveNothing() {
        let flow = CalmCheckFlow(exerciseID: "breath", at: at, enabled: true)
        flow.recordPulse(.unclear(.noFinger))
        flow.finishBefore()
        #expect(flow.savable == nil)
    }

    @Test func breathingKeepsFirstAndLastClearEstimates() {
        let flow = CalmCheckFlow(exerciseID: "breath", at: at, enabled: false)
        flow.recordBreathing(nil)
        flow.recordBreathing(14.2)
        flow.recordBreathing(nil)
        flow.recordBreathing(11)
        flow.recordBreathing(8.4)
        #expect(flow.savable?.breathsStart == 14.2)
        #expect(flow.savable?.breathsEnd == 8.4)
    }

    @Test func resultLinesKeepEstimatesAndAnswersApart() {
        var check = CalmCheck(exerciseID: "breath", at: at)
        check.bpmBefore = 78.4
        check.bpmAfter = 66.2
        check.tenseBefore = 4
        check.tenseAfter = 2
        check.breathsStart = 14.2
        check.breathsEnd = 8.4
        #expect(CalmCheckLine.lines(for: check) == [
            CalmCheckLine(text: "Heart rate 78 → 66 bpm", source: .camera),
            CalmCheckLine(text: "Breathing about 14 → 8 a minute", source: .microphone),
            CalmCheckLine(text: "You felt tense → a little tense", source: .you),
        ])
        var partial = CalmCheck(exerciseID: "breath", at: at)
        partial.bpmBefore = 71
        partial.tenseAfter = 1
        #expect(CalmCheckLine.lines(for: partial) == [
            CalmCheckLine(text: "Heart rate 71 bpm before", source: .camera),
            CalmCheckLine(text: "You felt calm after", source: .you),
        ])
        #expect(CalmCheckLine.Source.camera.label == "Estimate from your phone's camera")
        #expect(CalmCheckLine.Source.you.label == "What you told us")
        #expect(TensionScale.labels == ["Calm", "A little tense", "Somewhat tense", "Tense", "Very tense"])
    }
}

struct BreathGateTests {
    @Test func listensOnlyWhenAllowed() {
        #expect(BreathGate.canListen(enabled: true, soundSessionActive: false, category: .windDown))
        #expect(BreathGate.canListen(enabled: true, soundSessionActive: false, category: .awakeAtNight))
        #expect(!BreathGate.canListen(enabled: false, soundSessionActive: false, category: .windDown))
        #expect(!BreathGate.canListen(enabled: true, soundSessionActive: true, category: .windDown))
        #expect(!BreathGate.canListen(enabled: true, soundSessionActive: false, category: .morningReset))
        #expect(!BreathGate.canListen(enabled: true, soundSessionActive: false, category: .learn))
    }
}
