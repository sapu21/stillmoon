import Foundation

/// Breaths per minute from a microphone loudness envelope. Works in a quiet room; returns nil whenever unsure.
enum BreathAnalyzer {
    static let minimumSeconds = 20.0

    static func rms(_ samples: [Float]) -> Double {
        guard !samples.isEmpty else { return 0 }
        return sqrt(samples.reduce(0.0) { $0 + Double($1) * Double($1) } / Double(samples.count))
    }

    /// `envelope` is loudness sampled `sampleRate` times a second.
    static func rate(envelope: [Double], sampleRate: Double) -> Double? {
        guard Double(envelope.count) >= minimumSeconds * sampleRate else { return nil }
        let level = Signal.mean(envelope)
        guard level > 0 else { return nil }
        let wave = Signal.detrend(Signal.movingAverage(envelope, window: Int(sampleRate * 0.5)),
                                  window: Int(sampleRate * 6))
        let spread = Signal.standardDeviation(wave)
        guard spread / level > 0.03 else { return nil }

        let breaths = Signal.peaks(wave, minDistance: Int(sampleRate * 1.5), threshold: 0.5 * spread).map { $0 / sampleRate }
        let intervals = zip(breaths.dropFirst(), breaths).map { $0 - $1 }
        guard intervals.count >= 2 else { return nil }
        let typical = Signal.median(intervals)
        guard Signal.autocorrelation(wave, lag: Int((typical * sampleRate).rounded())) >= 0.4 else { return nil }
        let perMinute = 60 / typical
        return (4...30).contains(perMinute) ? perMinute : nil
    }
}
