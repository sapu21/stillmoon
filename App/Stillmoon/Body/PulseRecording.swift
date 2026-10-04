import Foundation

/// Decides which camera frames count toward a pulse reading. Pure, so its timing rules are testable:
/// the clock starts only once a fingertip covers the lens and exposure has settled, and any gap in frames
/// (app in the background, camera interrupted) starts over rather than skewing the frame rate.
struct PulseRecording {
    enum Status: Equatable {
        case waitingForFinger
        case settling
        case measuring(progress: Double)
        /// Frames stopped arriving for a while; the reading started over.
        case interrupted
        case done(PulseResult)
    }

    static let settleSeconds = 2.0
    static let maxGap = 0.25

    let seconds: Double
    private(set) var progress = 0.0
    private var frames: [PulseFrame] = []
    private var fingerSince: Double?
    private var measureStart: Double?
    private var lastTime: Double?
    private var result: PulseResult?

    init(seconds: Double) {
        self.seconds = seconds
    }

    mutating func add(_ frame: PulseFrame, at time: Double) -> Status {
        if let result { return .done(result) }
        defer { lastTime = time }
        if let lastTime, time - lastTime > Self.maxGap {
            frames = []
            fingerSince = nil
            measureStart = nil
            progress = 0
            return .interrupted
        }
        guard let fingerSince else {
            if PulseAnalyzer.isCovering(frame) { self.fingerSince = time; return .settling }
            return .waitingForFinger
        }
        if time - fingerSince < Self.settleSeconds { return .settling }
        let start = measureStart ?? time
        measureStart = start
        frames.append(frame)
        let elapsed = time - start
        guard elapsed >= seconds else {
            progress = elapsed / seconds
            return .measuring(progress: progress)
        }
        progress = 1
        let done = PulseAnalyzer.analyze(frames, fps: Double(frames.count - 1) / elapsed)
        result = done
        return .done(done)
    }
}
