import Foundation
import Testing
@testable import Stillmoon

struct PulseRecordingTests {
    /// Feeds frames at 30 fps starting at `from` seconds; returns the last status.
    @discardableResult
    func feed(_ recording: inout PulseRecording, _ frames: [PulseFrame], from: Double) -> PulseRecording.Status {
        var status = PulseRecording.Status.waitingForFinger
        for (i, frame) in frames.enumerated() { status = recording.add(frame, at: from + Double(i) / 30) }
        return status
    }

    @Test func timingStartsOnceTheFingerIsOnAndSettled() {
        var recording = PulseRecording(seconds: 45)
        let uncovered = (0..<150).map { _ in PulseFrame(r: 120, g: 118, b: 110) } // 5 s getting ready
        #expect(feed(&recording, uncovered, from: 0) == .waitingForFinger)
        let pulse = Synthetic.pulse(beats: Synthetic.beats(every: 60.0 / 70, seconds: 48), seconds: 48)
        let status = feed(&recording, pulse, from: 5)
        guard case .done(.reading(let bpm, _)) = status else { Issue.record("expected a reading, got \(status)"); return }
        #expect(abs(bpm - 70) <= 2)
    }

    @Test func aGapInFramesStartsOver() {
        var recording = PulseRecording(seconds: 45)
        let pulse = Synthetic.pulse(beats: Synthetic.beats(every: 0.8, seconds: 20), seconds: 20)
        feed(&recording, pulse, from: 0)
        let afterGap = recording.add(PulseFrame(r: 180, g: 40, b: 35), at: 25) // 5 s with no frames (app in background)
        #expect(afterGap == .interrupted)
        #expect(recording.progress == 0)
    }

    @Test func progressMovesWhileMeasuring() {
        var recording = PulseRecording(seconds: 45)
        let pulse = Synthetic.pulse(beats: Synthetic.beats(every: 0.8, seconds: 20), seconds: 20)
        guard case .measuring(let progress) = feed(&recording, pulse, from: 0) else { Issue.record("expected measuring"); return }
        #expect(progress > 0.3 && progress < 0.45) // about 18 of 45 s after 2 s of settling
    }
}

struct BreathReviewTests {
    @Test func slowWindDownBreathingReadsCorrectly() {
        let rate = BreathAnalyzer.rate(envelope: Synthetic.breathing(perMinute: 6, seconds: 60), sampleRate: 20)
        #expect(rate.map { abs($0 - 6) <= 1 } == true, "got \(String(describing: rate))")
    }

    @Test func audibleInhaleAndExhaleAreOneBreath() {
        // Each 10 s breath has two sounds, 3 s apart: never report 12 a minute.
        let envelope = (0..<1200).map { i -> Double in
            let t = (Double(i) / 20).truncatingRemainder(dividingBy: 10)
            return 1 + 0.5 * exp(-pow(t - 2, 2) / 0.5) + 0.45 * exp(-pow(t - 5, 2) / 0.5)
        }
        let rate = BreathAnalyzer.rate(envelope: envelope, sampleRate: 20)
        #expect(rate == nil || abs(rate! - 6) <= 1, "got \(String(describing: rate))")
    }

    @Test func chunkerKeepsTwentyLevelsASecondAcrossOddBuffers() {
        var chunker = EnvelopeChunker(chunk: 2400) // 48 kHz / 20
        var levels = 0
        for _ in 0..<117 { levels += chunker.append([Float](repeating: 0.5, count: 4096)).count } // ~10 s of 4096-frame buffers
        #expect(levels == 117 * 4096 / 2400)
    }
}

struct CalmFlowReviewTests {
    let at = TestEnv.d(2026, 10, 4, 21)

    @Test func tensionIsWrittenOnceWithTheFinalAnswer() {
        let flow = CalmCheckFlow(exerciseID: "breath", at: at, enabled: true)
        flow.recordTension(4)
        flow.recordTension(2)
        #expect(flow.finishBefore() == 2)
        flow.startAfter()
        #expect(flow.finishAfter() == nil) // skipped after
    }

    @Test func breathingAloneIsNotSavedWhenCalmChecksAreOff() {
        let flow = CalmCheckFlow(exerciseID: "awake", at: at, enabled: false)
        flow.recordBreathing(9)
        #expect(flow.savable == nil)
    }
}
