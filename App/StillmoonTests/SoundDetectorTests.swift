import Foundation
import SoundAnalysis
import Testing
@testable import Stillmoon

struct SoundDetectorTests {
    @Test func builtInClassifierHasOurLabels() throws {
        let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
        #expect(SoundAnalysisDetector.wantedIdentifiers.isSubset(of: Set(request.knownClassifications)))
    }

    @Test func fakeEmitsItsScriptOnStart() throws {
        let script = FakeSoundDetector.lastNightScript(now: TestEnv.d(2026, 10, 2, 9), calendar: TestEnv.cal)
        let fake = FakeSoundDetector(script: script)
        let received = LockedBox<[SoundObservation]>([])
        try fake.start { obs in received.mutate { $0.append(obs) } }
        #expect(fake.isRunning)
        #expect(received.value == script)
        fake.stop()
        #expect(!fake.isRunning)
    }

    @Test func lastNightScriptIsInsideLastNight() {
        let script = FakeSoundDetector.lastNightScript(now: TestEnv.d(2026, 10, 2, 9), calendar: TestEnv.cal)
        #expect(!script.isEmpty)
        #expect(script.allSatisfy { $0.time > TestEnv.d(2026, 10, 1, 23) && $0.time < TestEnv.d(2026, 10, 2, 6) })
    }
}

/// Tiny thread-safe box for collecting callback values in tests.
nonisolated final class LockedBox<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: T
    init(_ value: T) { stored = value }
    var value: T { lock.withLock { stored } }
    func mutate(_ f: (inout T) -> Void) { lock.withLock { f(&stored) } }
}
