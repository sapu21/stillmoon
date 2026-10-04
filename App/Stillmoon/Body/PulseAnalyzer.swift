import Foundation

/// Average color of the camera's center region for one frame (0...255 per channel).
struct PulseFrame: Equatable, Sendable {
    let r: Double
    let g: Double
    let b: Double
}

enum PulseIssue: Equatable, Sendable {
    /// The fingertip is not covering the camera and flash.
    case noFinger
    /// Not enough frames for a steady estimate.
    case tooShort
    /// Movement, pressure changes or irregular beats: no number is better than a wrong one.
    case noisy
}

enum PulseResult: Equatable, Sendable {
    /// Heart rate in beats per minute and RMSSD heart rate variability in milliseconds.
    case reading(bpm: Double, hrv: Double)
    case unclear(PulseIssue)
}

/// Heart rate from a fingertip over the flash (photoplethysmography). An estimate for a person sitting still,
/// never a medical measurement; anything doubtful returns `.unclear`.
enum PulseAnalyzer {
    static let minimumSeconds = 20.0

    /// A lit fingertip makes the frame strongly red.
    static func isCovering(_ frame: PulseFrame) -> Bool {
        frame.r > 60 && frame.r > 1.8 * frame.g && frame.r > 1.8 * frame.b
    }

    static func analyze(_ frames: [PulseFrame], fps: Double) -> PulseResult {
        guard Double(frames.count) >= minimumSeconds * fps else { return .unclear(.tooShort) }
        let covered = frames.filter(isCovering).count
        guard Double(covered) >= 0.9 * Double(frames.count) else { return .unclear(.noFinger) }

        let red = frames.map(\.r)
        let wave = Signal.movingAverage(Signal.detrend(red, window: Int(fps)), window: max(1, Int(fps * 0.1)))
        let spread = Signal.standardDeviation(wave)
        guard spread > 0.05 else { return .unclear(.noisy) }

        let beats = Signal.peaks(wave, minDistance: Int(fps * 0.33), threshold: 0.3 * spread).map { $0 / fps }
        let intervals = zip(beats.dropFirst(), beats).map { $0 - $1 }
        guard intervals.count >= 12 else { return .unclear(.noisy) }

        let typical = Signal.median(intervals)
        guard typical >= 0.33, typical <= 1.5 else { return .unclear(.noisy) }
        let steady = intervals.map { abs($0 - typical) / typical <= 0.3 }
        guard Double(steady.filter { !$0 }.count) <= 0.25 * Double(intervals.count) else { return .unclear(.noisy) }
        guard Signal.autocorrelation(wave, lag: Int((typical * fps).rounded())) >= 0.4 else { return .unclear(.noisy) }

        var differences: [Double] = []
        for i in 1..<intervals.count where steady[i] && steady[i - 1] {
            differences.append((intervals[i] - intervals[i - 1]) * 1000)
        }
        let rmssd = differences.isEmpty ? 0 : sqrt(Signal.mean(differences.map { $0 * $0 }))
        return .reading(bpm: 60 / typical, hrv: rmssd)
    }
}
