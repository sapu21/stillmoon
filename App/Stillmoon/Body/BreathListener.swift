import AVFoundation
import Observation
import StillmoonCore

/// When the player may listen for breathing: the user turned it on, no sleep session owns the microphone,
/// and the exercise is a calming one.
enum BreathGate {
    static func canListen(enabled: Bool, soundSessionActive: Bool, category: ExerciseCategory) -> Bool {
        enabled && !soundSessionActive && (category == .windDown || category == .awakeAtNight)
    }
}

/// Turns microphone input into a loudness envelope (20 values a second) and estimates breaths a minute
/// over the last 30 seconds. Audio is never stored; only the envelope numbers are kept, in memory.
@Observable final class BreathListener {
    static let envelopeRate = 20.0
    static let window = 30.0

    /// Latest clear estimate, or nil while unsure.
    private(set) var rate: Double?
    @ObservationIgnored private var engine: AVAudioEngine?
    @ObservationIgnored private var envelope: [Double] = []
    @ObservationIgnored private var sinceEstimate = 0

    func start() {
        guard engine == nil else { return }
        Task {
            guard await AVAudioApplication.requestRecordPermission() else { return }
            begin()
        }
    }

    private func begin() {
        guard engine == nil else { return }
        let engine = AVAudioEngine()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers, .defaultToSpeaker])
            try session.setActive(true)
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            let chunk = max(1, Int(format.sampleRate / Self.envelopeRate))
            input.installTap(onBus: 0, bufferSize: AVAudioFrameCount(chunk * 4), format: format) { [weak self] buffer, _ in
                guard let data = buffer.floatChannelData?[0] else { return }
                let count = Int(buffer.frameLength)
                var levels: [Double] = []
                var start = 0
                while start < count {
                    let end = min(count, start + chunk)
                    levels.append(BreathAnalyzer.rms(Array(UnsafeBufferPointer(start: data + start, count: end - start))))
                    start = end
                }
                Task { @MainActor in self?.append(levels) }
            }
            try engine.start()
            self.engine = engine
        } catch {
            engine.inputNode.removeTap(onBus: 0)
        }
    }

    func stop() {
        guard let engine else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        self.engine = nil
        envelope = []
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func append(_ levels: [Double]) {
        guard engine != nil else { return }
        envelope.append(contentsOf: levels)
        let keep = Int(Self.window * Self.envelopeRate)
        if envelope.count > keep { envelope.removeFirst(envelope.count - keep) }
        sinceEstimate += levels.count
        // Re-estimate every 5 seconds.
        if sinceEstimate >= Int(5 * Self.envelopeRate) {
            sinceEstimate = 0
            rate = BreathAnalyzer.rate(envelope: envelope, sampleRate: Self.envelopeRate)
        }
    }
}
