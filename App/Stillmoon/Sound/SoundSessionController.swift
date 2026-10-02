import AVFAudio
import Foundation
import Observation
import StillmoonCore

struct FeatureFlags: Equatable {
    /// Remote in Plan 5 (FR-18); local default until then.
    var soundDetection = true
}

enum SoundSessionError: Error, Equatable {
    case notAvailable, permissionDenied, couldNotStart
}

/// One user-started overnight session at a time. Never notifies or makes sound.
@Observable final class SoundSessionController {
    enum State: Equatable {
        case idle
        case running(since: Date)
        case paused(since: Date)
    }

    static let lowBattery = 0.3

    @ObservationIgnored private let store: LocalStore
    @ObservationIgnored private let detector: SoundDetecting
    @ObservationIgnored private let permission: MicrophonePermission
    @ObservationIgnored private let battery: BatteryReading
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let flags: () -> FeatureFlags
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var debouncer = SoundEventDebouncer()
    @ObservationIgnored private var sessionID: UUID?
    @ObservationIgnored private var pausedByInterruption = false
    @ObservationIgnored private var starting = false
    @ObservationIgnored private var tickTask: Task<Void, Never>?

    /// Set when a resume after an interruption fails; cleared on the next successful start or resume.
    private(set) var lastError: SoundSessionError?

    private(set) var state: State = .idle

    init(store: LocalStore, detector: SoundDetecting, permission: MicrophonePermission, battery: BatteryReading,
         settings: SettingsStore, flags: @escaping () -> FeatureFlags, now: @escaping () -> Date = Date.init) {
        self.store = store
        self.detector = detector
        self.permission = permission
        self.battery = battery
        self.settings = settings
        self.flags = flags
        self.now = now
    }

    var isActive: Bool { state != .idle }
    var isAvailable: Bool { flags().soundDetection && settings.settings.soundDetectionEnabled }

    func requestPermission() async -> Bool { await permission.request() }

    func needsBatteryWarning() -> Bool {
        let reading = battery.read()
        guard let level = reading.level else { return false }
        return !reading.charging && level < Self.lowBattery
    }

    func start() async throws {
        guard state == .idle, !starting else { return }
        guard isAvailable else { throw SoundSessionError.notAvailable }
        starting = true
        defer { starting = false }
        guard await permission.request() else { throw SoundSessionError.permissionDenied }
        guard state == .idle else { return }
        let started = now()
        let id = store.startSoundSession(at: started)
        sessionID = id
        debouncer = SoundEventDebouncer()
        // Running before the detector starts, so observations delivered immediately are kept.
        state = .running(since: started)
        do {
            try startDetector()
        } catch {
            store.deleteSoundSession(id)
            sessionID = nil
            state = .idle
            throw SoundSessionError.couldNotStart
        }
        lastError = nil
        startTicking()
    }

    func pause() {
        pausedByInterruption = false
        pauseListening(suspend: false)
    }

    /// `suspend` keeps the audio session alive (interruptions, failures); a user pause releases it.
    private func pauseListening(suspend: Bool) {
        guard case .running(let since) = state else { return }
        stopTicking()
        if suspend { detector.suspend() } else { detector.stop() }
        saveClosed(debouncer.flush())
        state = .paused(since: since)
    }

    func resume() throws {
        pausedByInterruption = false
        do { try resumeListening() } catch {
            lastError = .couldNotStart
            throw error
        }
    }

    private func resumeListening() throws {
        guard case .paused(let since) = state else { return }
        state = .running(since: since)
        do {
            try startDetector()
        } catch {
            state = .paused(since: since)
            throw error
        }
        lastError = nil
        startTicking()
    }

    func stop() {
        guard isActive else { return }
        pausedByInterruption = false
        stopTicking()
        detector.stop()
        saveClosed(debouncer.flush())
        if let id = sessionID { store.endSoundSession(id, at: now()) }
        sessionID = nil
        state = .idle
    }

    /// Phone calls and Siri interrupt the microphone; pause and count, resume when allowed.
    func handleInterruption(began: Bool) {
        if began {
            guard case .running = state else { return }
            if let id = sessionID { store.recordInterruption(sessionID: id) }
            pauseListening(suspend: true)
            pausedByInterruption = true
        } else {
            guard pausedByInterruption else { return }
            pausedByInterruption = false
            do { try resumeListening() } catch { lastError = .couldNotStart }
        }
    }

    /// Lets main-actor hops from a background detector finish (tests only; the fake delivers synchronously).
    func drainForTesting() async {
        await Task.yield()
    }

    private func startDetector() throws {
        let captured = sessionID
        try detector.start(onObservation: { [weak self] observation in
            if Thread.isMainThread {
                MainActor.assumeIsolated { self?.receive(observation, session: captured) }
            } else {
                Task { @MainActor in self?.receive(observation, session: captured) }
            }
        }, onFailure: { [weak self] in
            if Thread.isMainThread {
                MainActor.assumeIsolated { self?.detectorFailed(session: captured) }
            } else {
                Task { @MainActor in self?.detectorFailed(session: captured) }
            }
        })
    }

    private func detectorFailed(session: UUID?) {
        guard session == sessionID, case .running = state else { return }
        pauseListening(suspend: true)
        lastError = .couldNotStart
    }

    /// Saves events that went quiet, so a long quiet night doesn't hold them in memory until the end.
    private func startTicking() {
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                if Task.isCancelled { break }
                self?.tickForTesting()
            }
        }
    }

    private func stopTicking() {
        tickTask?.cancel()
        tickTask = nil
    }

    /// One close-stale pass (the 60-second loop calls this).
    func tickForTesting() {
        guard case .running = state else { return }
        saveClosed(debouncer.closeStale(now: now()))
    }

    private func receive(_ observation: SoundObservation, session: UUID?) {
        guard session == sessionID, case .running = state, let label = SoundLabel(classifierIdentifier: observation.identifier) else { return }
        saveClosed(debouncer.add(SoundObservationInput(label: label, confidence: observation.confidence, time: observation.time)))
    }

    private func saveClosed(_ events: [SoundEvent]) {
        guard let id = sessionID else { return }
        store.addSoundEvents(events, sessionID: id)
    }
}
