import Foundation
import Testing
import StillmoonCore
@testable import Stillmoon

private nonisolated final class Fired: @unchecked Sendable { nonisolated(unsafe) var value = false }

struct SoundSessionControllerTests {
    let now = TestEnv.d(2026, 10, 1, 23)

    func make(enabled: Bool = true, granted: Bool = true, flag: Bool = true,
              script: [SoundObservation] = [], battery: BatteryState = BatteryState(level: 0.9, charging: false))
    throws -> (SoundSessionController, LocalStore, FakeSoundDetector, FakeMicrophonePermission) {
        let store = try TestEnv.store()
        let settings = TestEnv.settings()
        settings.settings.soundDetectionEnabled = enabled
        let detector = FakeSoundDetector(script: script)
        let permission = FakeMicrophonePermission(granted: granted)
        let controller = SoundSessionController(store: store, detector: detector, permission: permission,
                                                battery: FakeBattery(state: battery), settings: settings,
                                                flags: { FeatureFlags(soundDetection: flag) }, now: { now })
        return (controller, store, detector, permission)
    }

    func obs(_ id: String, _ h: Int, _ m: Int, _ s: Int = 0, _ c: Double = 0.8) -> SoundObservation {
        SoundObservation(identifier: id, confidence: c, time: TestEnv.d(2026, 10, 2, h, m).addingTimeInterval(Double(s)))
    }

    @Test func startRunsAndStopSavesMergedEvents() async throws {
        let (c, store, detector, _) = try make(script: [obs("snoring", 2, 0), obs("snoring", 2, 0, 10), obs("speech", 3, 0), obs("dog_bark", 3, 1)])
        try await c.start()
        #expect(c.state == .running(since: now))
        #expect(c.isActive)
        #expect(detector.isRunning)
        await c.drainForTesting()
        c.stop()
        #expect(c.state == .idle)
        #expect(!detector.isRunning)
        let events = store.soundEvents(from: .distantPast, to: .distantFuture)
        #expect(events.map(\.label) == [.snoringLike, .speechLike])
        #expect(store.openSessionID() == nil)
    }

    @Test func startFailsWhenPermissionDenied() async throws {
        let (c, store, detector, _) = try make(granted: false)
        await #expect(throws: SoundSessionError.permissionDenied) { try await c.start() }
        #expect(c.state == .idle)
        #expect(!detector.isRunning)
        #expect(store.openSessionID() == nil)
    }

    @Test func notAvailableWhenFlagOffOrSettingOff() async throws {
        let (flagOff, _, _, p1) = try make(flag: false)
        #expect(!flagOff.isAvailable)
        await #expect(throws: SoundSessionError.notAvailable) { try await flagOff.start() }
        #expect(p1.requests == 0)
        let (settingOff, _, _, _) = try make(enabled: false)
        #expect(!settingOff.isAvailable)
    }

    @Test func pauseStopsListeningAndResumeRestarts() async throws {
        let (c, _, detector, _) = try make()
        try await c.start()
        c.pause()
        #expect(c.state == .paused(since: now))
        #expect(!detector.isRunning)
        try c.resume()
        #expect(c.state == .running(since: now))
        #expect(detector.isRunning)
    }

    @Test func interruptionPausesAndCounts() async throws {
        let (c, store, detector, _) = try make()
        try await c.start()
        let session = store.openSessionID()
        c.handleInterruption(began: true)
        #expect(!detector.isRunning)
        c.handleInterruption(began: false)
        #expect(detector.isRunning)
        #expect(session != nil)
        #expect(store.interruptions(sessionID: session!) == 1)
    }

    @Test func interruptionEndDoesNotResumeUserPause() async throws {
        let (c, _, detector, _) = try make()
        try await c.start()
        c.pause()
        c.handleInterruption(began: false)
        #expect(c.state == .paused(since: now))
        #expect(!detector.isRunning)
    }

    @Test func doubleStartOpensOneSession() async throws {
        let (c, store, _, _) = try make()
        async let a: Void = c.start()
        async let b: Void = c.start()
        _ = try await (a, b)
        #expect(c.state == .running(since: now))
        #expect(store.openSessionID() != nil)
        c.stop()
        #expect(store.openSessionID() == nil)
    }

    @Test func flagsChangeIsObserved() throws {
        let env = AppEnvironment(store: try TestEnv.store(), settings: TestEnv.settings(), catalog: .empty)
        let fired = Fired()
        withObservationTracking({ _ = env.flags }, onChange: { fired.value = true })
        env.flags.soundDetection = false
        #expect(fired.value)
    }

    @Test func flagChangeOnEnvironmentDisablesSound() throws {
        let settings = TestEnv.settings()
        settings.settings.soundDetectionEnabled = true
        let env = AppEnvironment(store: try TestEnv.store(), settings: settings, catalog: .empty)
        #expect(env.sound.isAvailable)
        env.flags.soundDetection = false
        #expect(!env.sound.isAvailable)
    }

    @Test(arguments: [(BatteryState(level: 0.2, charging: false), true),
                      (BatteryState(level: 0.2, charging: true), false),
                      (BatteryState(level: 0.5, charging: false), false),
                      (BatteryState(level: nil, charging: false), false)])
    func batteryWarning(state: BatteryState, warns: Bool) throws {
        let (c, _, _, _) = try make(battery: state)
        #expect(c.needsBatteryWarning() == warns)
    }

    @Test func launchRecoversOrphanedSession() throws {
        let env = AppEnvironment.live(arguments: ["-ui-testing", "-fake-sound"])
        let session = env.store.startSoundSession(at: now)
        #expect(env.store.openSessionID() == session)
        env.store.closeOrphanedSessions()
        #expect(env.store.openSessionID() == nil)
        #expect(!env.sessionActive)
    }
}
