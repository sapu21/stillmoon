import AVFAudio
import Foundation
import SoundAnalysis

/// Live classification of microphone input on the device. No audio is kept.
final class SoundAnalysisDetector: SoundDetecting {
    static let wantedIdentifiers: Set<String> = ["snoring", "speech", "cough"]

    private let engine = AVAudioEngine()
    private var analyzer: SNAudioStreamAnalyzer?
    private var observer: ClassificationObserver?
    private let analysisQueue = DispatchQueue(label: "app.stillmoon.sound-analysis")
    private var isRunning = false
    private var tapInstalled = false
    private var onObservation: (@Sendable (SoundObservation) -> Void)?
    private var configObserver: NSObjectProtocol?

    func start(onObservation: @escaping @Sendable (SoundObservation) -> Void) throws {
        if isRunning { stop() }
        self.onObservation = onObservation
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement)
            try session.setActive(true)
            try buildAndStartEngine()
        } catch {
            teardown()
            throw error
        }
        configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil
        ) { [weak self] _ in
            Task { @MainActor in self?.rebuildAfterConfigurationChange() }
        }
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        teardown()
    }

    private func buildAndStartEngine() throws {
        guard let onObservation else { return }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        let analyzer = SNAudioStreamAnalyzer(format: format)
        let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
        let observer = ClassificationObserver(wanted: Self.wantedIdentifiers, onObservation: onObservation)
        try analyzer.add(request, withObserver: observer)
        self.analyzer = analyzer
        self.observer = observer

        input.installTap(onBus: 0, bufferSize: 8192, format: format,
                         block: Self.makeTapBlock(analyzer: analyzer, queue: analysisQueue))
        tapInstalled = true
        try engine.start()
    }

    private func removeTapAndDrain() {
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        engine.stop()
        analysisQueue.sync {}
        analyzer?.completeAnalysis()
        analyzer = nil
        observer = nil
    }

    private func teardown() {
        if let configObserver { NotificationCenter.default.removeObserver(configObserver) }
        configObserver = nil
        removeTapAndDrain()
        onObservation = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Route or format changed (e.g. headphones, interruption): rebuild with the new input format.
    private func rebuildAfterConfigurationChange() {
        guard isRunning else { return }
        removeTapAndDrain()
        do {
            try buildAndStartEngine()
        } catch {
            // Leave stopped; the session controller's interruption handling will pause.
            isRunning = false
            teardown()
        }
    }

    /// Built outside the main actor: the tap runs on an audio thread.
    private nonisolated static func makeTapBlock(analyzer: SNAudioStreamAnalyzer,
                                                 queue: DispatchQueue) -> AVAudioNodeTapBlock {
        nonisolated(unsafe) let analyzer = analyzer
        return { buffer, time in
            queue.async { analyzer.analyze(buffer, atAudioFramePosition: time.sampleTime) }
        }
    }
}

/// Receives classifier results on SoundAnalysis's queue.
nonisolated final class ClassificationObserver: NSObject, SNResultsObserving, @unchecked Sendable {
    private let wanted: Set<String>
    private let onObservation: @Sendable (SoundObservation) -> Void

    init(wanted: Set<String>, onObservation: @escaping @Sendable (SoundObservation) -> Void) {
        self.wanted = wanted
        self.onObservation = onObservation
    }

    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult else { return }
        let now = Date()
        for classification in result.classifications where wanted.contains(classification.identifier) {
            onObservation(SoundObservation(identifier: classification.identifier,
                                           confidence: classification.confidence, time: now))
        }
    }
}
