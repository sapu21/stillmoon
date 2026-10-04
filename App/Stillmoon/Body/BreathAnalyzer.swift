import Foundation

/// Breaths per minute from a microphone loudness envelope. Works in a quiet room; returns nil whenever unsure.
enum BreathAnalyzer {
    static let minimumSeconds = 20.0

    nonisolated static func rms(_ samples: [Float]) -> Double {
        guard !samples.isEmpty else { return 0 }
        return sqrt(samples.reduce(0.0) { $0 + Double($1) * Double($1) } / Double(samples.count))
    }

    /// `envelope` is loudness sampled `sampleRate` times a second.
    static func rate(envelope: [Double], sampleRate: Double) -> Double? {
        guard Double(envelope.count) >= minimumSeconds * sampleRate else { return nil }
        let level = Signal.mean(envelope)
        guard level > 0 else { return nil }
        // The trend window outlasts a slow wind-down breath (10 to 15 s) so it doesn't eat the breath itself.
        let wave = Signal.detrend(Signal.movingAverage(envelope, window: Int(sampleRate * 0.5)),
                                  window: Int(sampleRate * 15))
        let spread = Signal.standardDeviation(wave)
        guard spread / level > 0.03 else { return nil }

        let breaths = Signal.peaks(wave, minDistance: Int(sampleRate * 1.5), threshold: 0.5 * spread).map { $0 / sampleRate }
        let intervals = zip(breaths.dropFirst(), breaths).map { $0 - $1 }
        guard intervals.count >= 2 else { return nil }
        let typical = Signal.median(intervals)
        // Uneven gaps (an audible inhale and exhale, a cough) mean we can't tell breaths apart: say nothing.
        let steady = intervals.filter { abs($0 - typical) / typical <= 0.3 }.count
        guard Double(steady) >= 0.7 * Double(intervals.count) else { return nil }
        guard Signal.autocorrelation(wave, lag: Int((typical * sampleRate).rounded())) >= 0.4 else { return nil }
        let perMinute = 60 / typical
        return (4...30).contains(perMinute) ? perMinute : nil
    }
}

/// Turns raw microphone samples into loudness levels of exactly `chunk` samples each,
/// carrying leftovers across buffers so the envelope keeps its exact rate.
nonisolated struct EnvelopeChunker: Sendable {
    let chunk: Int
    private var pending: [Float] = []

    init(chunk: Int) {
        self.chunk = max(1, chunk)
    }

    mutating func append(_ samples: [Float]) -> [Double] {
        pending.append(contentsOf: samples)
        var levels: [Double] = []
        var start = 0
        while pending.count - start >= chunk {
            levels.append(BreathAnalyzer.rms(Array(pending[start..<(start + chunk)])))
            start += chunk
        }
        pending.removeFirst(start)
        return levels
    }
}
