import Foundation

struct SoundObservation: Sendable, Equatable {
    let identifier: String
    let confidence: Double
    let time: Date
}

protocol SoundDetecting: AnyObject {
    /// `onObservation` may be called on any thread.
    /// `onFailure` may be called on any thread, when the detector tears itself down after starting.
    func start(onObservation: @escaping @Sendable (SoundObservation) -> Void,
               onFailure: @escaping @Sendable () -> Void) throws
    /// Full teardown: audio session deactivated, handlers dropped.
    func stop()
    /// Stops listening but keeps the audio session alive so a later `start` can resume (interruptions).
    func suspend()
}

private struct FakeStartFailure: Error {}

/// Emits a fixed script when started. Used by tests and `-fake-sound`.
final class FakeSoundDetector: SoundDetecting {
    private let script: [SoundObservation]
    private var handler: (@Sendable (SoundObservation) -> Void)?
    private var failureHandler: (@Sendable () -> Void)?
    private(set) var isRunning = false
    private(set) var suspendCount = 0
    var failOnStart = false

    init(script: [SoundObservation] = []) {
        self.script = script
    }

    func start(onObservation: @escaping @Sendable (SoundObservation) -> Void,
               onFailure: @escaping @Sendable () -> Void) throws {
        if failOnStart { throw FakeStartFailure() }
        handler = onObservation
        failureHandler = onFailure
        isRunning = true
        script.forEach(onObservation)
    }

    func emit(_ observation: SoundObservation) {
        handler?(observation)
    }

    /// Simulates the detector dying while running.
    func fail() {
        isRunning = false
        failureHandler?()
    }

    func stop() {
        isRunning = false
        handler = nil
        failureHandler = nil
    }

    func suspend() {
        isRunning = false
        suspendCount += 1
    }

    /// Snoring at 02:00 and 02:00:10 (one event) and speech at 03:00, last night.
    static func lastNightScript(now: Date, calendar: Calendar) -> [SoundObservation] {
        let day = calendar.startOfDay(for: now)
        func at(_ h: Int, _ m: Int, _ s: Int) -> Date {
            calendar.date(bySettingHour: h, minute: m, second: s, of: day)!
        }
        return [
            SoundObservation(identifier: "snoring", confidence: 0.82, time: at(2, 0, 0)),
            SoundObservation(identifier: "snoring", confidence: 0.9, time: at(2, 0, 10)),
            SoundObservation(identifier: "speech", confidence: 0.7, time: at(3, 0, 0)),
        ]
    }
}
