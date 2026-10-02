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

    func needsBatteryWarning() -> Bool {
        let reading = battery.read()
        guard let level = reading.level else { return false }
        return !reading.charging && level < Self.lowBattery
    }

    func start() async throws {
        guard state == .idle else { return }
        guard isAvailable else { throw SoundSessionError.notAvailable }
        guard await permission.request() else { throw SoundSessionError.permissionDenied }
        let started = now()
        let id = store.startSoundSession(at: started)
        sessionID = id
        debouncer = SoundEventDebouncer()
        // Running before the detector starts, so observations delivered immediately are kept.
        state = .running(since: started)
        do {
            try startDetector()
        } catch {
            store.endSoundSession(id, at: started)
            sessionID = nil
            state = .idle
            throw SoundSessionError.couldNotStart
        }
    }

    func pause() {
        guard case .running(let since) = state else { return }
        detector.stop()
        saveClosed(debouncer.flush())
        state = .paused(since: since)
    }

    func resume() throws {
        guard case .paused(let since) = state else { return }
        state = .running(since: since)
        do {
            try startDetector()
        } catch {
            state = .paused(since: since)
            throw error
        }
    }

    func stop() {
        guard isActive else { return }
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
            pause()
        } else {
            try? resume()
        }
    }

    /// Lets main-actor hops from a background detector finish (tests only; the fake delivers synchronously).
    func drainForTesting() async {
        await Task.yield()
    }

    private func startDetector() throws {
        try detector.start { [weak self] observation in
            if Thread.isMainThread {
                MainActor.assumeIsolated { self?.receive(observation) }
            } else {
                Task { @MainActor in self?.receive(observation) }
            }
        }
    }

    private func receive(_ observation: SoundObservation) {
        guard case .running = state, let label = SoundLabel(classifierIdentifier: observation.identifier) else { return }
        saveClosed(debouncer.add(SoundObservationInput(label: label, confidence: observation.confidence, time: observation.time)))
    }

    private func saveClosed(_ events: [SoundEvent]) {
        guard let id = sessionID else { return }
        store.addSoundEvents(events, sessionID: id)
    }
}
