import Foundation
import Testing
@testable import Stillmoon

/// Deterministic noise so signal tests never flake.
struct SeededNoise {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    /// Uniform in -1...1.
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(1 << 53) * 2 - 1
    }
}

enum Synthetic {
    static let fps = 30.0

    /// Fingertip-on-flash frames: red-dominant, with a pulse bump at each beat time.
    static func pulse(beats: [Double], seconds: Double, noise: Double = 0.2, seed: UInt64 = 1) -> [PulseFrame] {
        var rng = SeededNoise(seed: seed)
        return (0..<Int(seconds * fps)).map { i in
            let t = Double(i) / fps
            let bump = beats.reduce(0) { $0 + exp(-pow(t - $1, 2) / (2 * 0.08 * 0.08)) }
            return PulseFrame(r: 180 + 4 * bump + noise * rng.next(), g: 40, b: 35)
        }
    }

    static func beats(every interval: Double, seconds: Double) -> [Double] {
        Array(stride(from: 0.5, to: seconds, by: interval))
    }

    /// Loudness envelope at 20 samples a second with a breath every 60 / perMinute seconds.
    static func breathing(perMinute: Double, seconds: Double, noise: Double = 0.03, seed: UInt64 = 2) -> [Double] {
        var rng = SeededNoise(seed: seed)
        return (0..<Int(seconds * 20)).map { i in
            let t = Double(i) / 20
            return 1 + 0.4 * sin(2 * .pi * perMinute / 60 * t) + noise * rng.next()
        }
    }
}

struct PulseAnalyzerTests {
    func bpm(_ result: PulseResult) -> Double? {
        if case .reading(let bpm, _) = result { return bpm }
        return nil
    }

    @Test func readsSteadyPulses() {
        for (interval, expected) in [(60.0 / 72, 72.0), (60.0 / 55, 55.0)] {
            let frames = Synthetic.pulse(beats: Synthetic.beats(every: interval, seconds: 45), seconds: 45)
            let reading = bpm(PulseAnalyzer.analyze(frames, fps: Synthetic.fps))
            #expect(reading.map { abs($0 - expected) <= 2 } == true, "expected \(expected), got \(String(describing: reading))")
        }
    }

    @Test func measuresBeatToBeatVariation() throws {
        var beats: [Double] = [0.5]
        while beats.last! < 45 { beats.append(beats.last! + (beats.count.isMultiple(of: 2) ? 0.8 : 0.9)) }
        guard case .reading(_, let hrv) = PulseAnalyzer.analyze(Synthetic.pulse(beats: beats, seconds: 45), fps: Synthetic.fps) else {
            Issue.record("expected a reading"); return
        }
        let measured = try #require(hrv)
        #expect(abs(measured - 100) <= 10) // successive differences of 100 ms
    }

    @Test func noFingerMeansNoNumber() {
        let frames = (0..<1350).map { _ in PulseFrame(r: 120, g: 118, b: 110) }
        #expect(PulseAnalyzer.analyze(frames, fps: Synthetic.fps) == .unclear(.noFinger))
        #expect(!PulseAnalyzer.isCovering(PulseFrame(r: 120, g: 118, b: 110)))
        #expect(PulseAnalyzer.isCovering(PulseFrame(r: 180, g: 40, b: 35)))
    }

    @Test func tooShortMeansNoNumber() {
        let frames = Synthetic.pulse(beats: Synthetic.beats(every: 0.8, seconds: 10), seconds: 10)
        #expect(PulseAnalyzer.analyze(frames, fps: Synthetic.fps) == .unclear(.tooShort))
    }

    @Test func noiseOrIrregularBeatsMeanNoNumber() {
        var rng = SeededNoise(seed: 7)
        let noise = (0..<1350).map { _ in PulseFrame(r: 180 + 4 * rng.next(), g: 40, b: 35) }
        #expect(PulseAnalyzer.analyze(noise, fps: Synthetic.fps) == .unclear(.noisy))
        let flat = (0..<1350).map { _ in PulseFrame(r: 180, g: 40, b: 35) }
        #expect(PulseAnalyzer.analyze(flat, fps: Synthetic.fps) == .unclear(.noisy))
        var beats: [Double] = [0.5]
        while beats.last! < 45 { beats.append(beats.last! + 0.9 + 0.5 * rng.next()) } // 0.4 to 1.4 s apart
        #expect(PulseAnalyzer.analyze(Synthetic.pulse(beats: beats, seconds: 45), fps: Synthetic.fps) == .unclear(.noisy))
    }
}

struct BreathAnalyzerTests {
    @Test func readsSteadyBreathing() {
        for expected in [9.0, 15.0] {
            let rate = BreathAnalyzer.rate(envelope: Synthetic.breathing(perMinute: expected, seconds: 40), sampleRate: 20)
            #expect(rate.map { abs($0 - expected) <= 1 } == true, "expected \(expected), got \(String(describing: rate))")
        }
    }

    @Test func unclearAudioMeansNoNumber() {
        #expect(BreathAnalyzer.rate(envelope: Array(repeating: 1, count: 800), sampleRate: 20) == nil)
        var rng = SeededNoise(seed: 3)
        let noise = (0..<800).map { _ in 1 + 0.5 * rng.next() }
        #expect(BreathAnalyzer.rate(envelope: noise, sampleRate: 20) == nil)
        #expect(BreathAnalyzer.rate(envelope: Synthetic.breathing(perMinute: 9, seconds: 10), sampleRate: 20) == nil)
    }

    @Test func rmsOfASignal() {
        #expect(BreathAnalyzer.rms([]) == 0)
        #expect(abs(BreathAnalyzer.rms([3, -3, 3, -3]) - 3) < 0.0001)
    }
}
