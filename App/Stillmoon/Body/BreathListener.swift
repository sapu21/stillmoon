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
    /// False once `stop()` runs, so a permission prompt that resolves late never starts the microphone.
    @ObservationIgnored private var wanted = false

    func start() {
        wanted = true
        guard engine == nil else { return }
        Task {
            guard await AVAudioApplication.requestRecordPermission(), wanted else { return }
            begin()
        }
    }

    private func begin() {
        guard engine == nil, wanted else { return }
        let engine = AVAudioEngine()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers, .defaultToSpeaker])
            try session.setActive(true)
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { return }
            let chunk = max(1, Int(format.sampleRate / Self.envelopeRate))
            input.installTap(onBus: 0, bufferSize: AVAudioFrameCount(chunk * 2), format: format,
                             block: Self.makeTapBlock(chunk: chunk) { [weak self] levels in
                                 Task { @MainActor in self?.append(levels) }
                             })
            try engine.start()
            self.engine = engine
        } catch {
            engine.inputNode.removeTap(onBus: 0)
        }
    }

    func stop() {
        wanted = false
        rate = nil
        envelope = []
        sinceEstimate = 0
        guard let engine else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        self.engine = nil
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

    /// Built outside the main actor: the tap runs on an audio thread (same pattern as SoundAnalysisDetector).
    private nonisolated static func makeTapBlock(chunk: Int,
                                                 sink: @escaping @Sendable ([Double]) -> Void) -> AVAudioNodeTapBlock {
        let box = ChunkerBox(chunker: EnvelopeChunker(chunk: chunk))
        return { buffer, _ in
            guard let data = buffer.floatChannelData?[0] else { return }
            let samples = Array(UnsafeBufferPointer(start: data, count: Int(buffer.frameLength)))
            let levels = box.chunker.append(samples)
            if !levels.isEmpty { sink(levels) }
        }
    }
}

/// Holds the chunker for the audio thread; the tap is its only user, called serially.
private nonisolated final class ChunkerBox: @unchecked Sendable {
    var chunker: EnvelopeChunker
    init(chunker: EnvelopeChunker) { self.chunker = chunker }
}
